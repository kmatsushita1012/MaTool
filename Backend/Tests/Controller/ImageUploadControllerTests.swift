import Dependencies
import Shared
import Testing
@testable import Backend

struct ImageUploadControllerTests {
    private let next: Handler = { _ in throw TestError.intentional }

    @Test("本部管理者の有効なリクエストは署名URLをレスポンスに返す")
    func authorizedUploadRequestReturnsPresignedURL() async throws {
        let spy = ImageUploadUsecaseSpy()
        let controller = withDependencies {
            $0[ImageUploadUsecaseKey.self] = spy
        } operation: {
            ImageUploadController()
        }
        let upload = ImageUploadURLRequest(
            target: .init(type: .festival, id: "festival", variant: .light),
            contentType: "image/jpeg"
        )
        var request = Application.Request.make(
            method: .post,
            path: "/images/upload-url",
            body: try upload.toString()
        )
        request.user = .headquarter("festival")

        let response = try await controller.post(request, next: next)
        let decoded = try ImageUploadURLResponse.from(response.body)

        #expect(response.statusCode == 200)
        #expect(response.headers["Content-Type"] == "application/json")
        #expect(decoded.url == "https://upload.example.test/signed")
        #expect(decoded.path == "temporary/festivals/festival/light.jpg")
        let calls = await spy.recordedRequests()
        #expect(calls.count == 1)
        #expect(calls.first?.0.target.id == "festival")
        #expect(calls.first?.1 == .headquarter("festival"))
    }

    @Test("未ログインとGuestは署名URLの作成を拒否しUsecaseを呼ばない")
    func rejectsUnauthenticatedAndGuestRequest() async {
        let spy = ImageUploadUsecaseSpy()
        let controller = withDependencies {
            $0[ImageUploadUsecaseKey.self] = spy
        } operation: { ImageUploadController() }
        var request = Application.Request.make(
            method: .post,
            path: "/images/upload-url",
            body: #"{"target":{"type":"festival","id":"festival","variant":"light"},"contentType":"image/jpeg"}"#
        )

        await #expect(throws: Error.self) {
            try await controller.post(request, next: next)
        }
        request.user = .guest
        await #expect(throws: Error.self) {
            try await controller.post(request, next: next)
        }
        #expect(await spy.recordedRequests().isEmpty)
    }

    @Test("不正JSONと必須項目不足は400のbadRequestを返す")
    func rejectsInvalidRequestBody() async {
        let spy = ImageUploadUsecaseSpy()
        let controller = withDependencies {
            $0[ImageUploadUsecaseKey.self] = spy
        } operation: { ImageUploadController() }
        for text in [#"{"invalid":true}"#, "not json"] {
            var request = Application.Request.make(
                method: .post, path: "/images/upload-url", body: text
            )
            request.user = .district("district")
            do {
                _ = try await controller.post(request, next: next)
                Issue.record("不正なアップロード本文が受理されました")
            } catch let error as Error {
                #expect(error.statusCode == 400)
            } catch {
                Issue.record("予期しないエラー \(error)")
            }
        }
        #expect(await spy.recordedRequests().isEmpty)
    }

    @Test("署名生成の失敗は成功レスポンスに変換せず伝える")
    func propagatesUsecaseFailure() async throws {
        let spy = ImageUploadUsecaseSpy(shouldFail: true)
        let controller = withDependencies {
            $0[ImageUploadUsecaseKey.self] = spy
        } operation: { ImageUploadController() }
        let body = ImageUploadURLRequest(
            target: .init(type: .district, id: "district", variant: .dark),
            contentType: "image/jpeg"
        )
        var request = Application.Request.make(
            method: .post,
            path: "/images/upload-url",
            body: try body.toString()
        )
        request.user = .district("district")

        await #expect(throws: TestError.intentional) {
            try await controller.post(request, next: next)
        }
        #expect(await spy.recordedRequests().count == 1)
    }
}
