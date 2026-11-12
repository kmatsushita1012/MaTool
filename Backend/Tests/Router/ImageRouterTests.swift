import Dependencies
import Shared
import Testing
@testable import Backend

struct ImageRouterTests {
    @Test("画像署名URLエンドポイントはPOSTのみ登録される")
    func onlyPostIsRegistered() async {
        let spy = ImageUploadControllerSpy()
        let app = withDependencies {
            $0[ImageUploadControllerKey.self] = spy
        } operation: {
            Application { ImageRouter() }
        }

        let post = await app.handle(.make(method: .post, path: "/images/upload-url"))
        let get = await app.handle(.make(method: .get, path: "/images/upload-url"))
        let missing = await app.handle(.make(method: .post, path: "/images/missing"))

        #expect(post.statusCode == 200)
        #expect(get.statusCode == 404)
        #expect(missing.statusCode == 404)
        #expect(await spy.recorded().map(\.path) == ["/images/upload-url"])
    }

    @Test("マッチしたPOSTリクエストは現在の認証ユーザー情報とともにControllerへ渡す")
    func forwardsCurrentUserToController() async {
        let spy = ImageUploadControllerSpy()
        let app = withDependencies {
            $0[ImageUploadControllerKey.self] = spy
        } operation: {
            Application { ImageRouter() }
        }
        var request = Application.Request.make(method: .post, path: "/images/upload-url")
        request.user = .headquarter("festival")

        let response = await app.handle(request)

        #expect(response.statusCode == 200)
        let actual = await spy.recorded()
        #expect(actual.count == 1)
        #expect(actual.first?.user == .headquarter("festival"))
    }

    @Test("ControllerのエラーはApplicationの500に変換される")
    func controllerFailureIsNotHidden() async {
        let spy = ImageUploadControllerSpy(shouldFail: true)
        let app = withDependencies {
            $0[ImageUploadControllerKey.self] = spy
        } operation: {
            Application { ImageRouter() }
        }

        let response = await app.handle(.make(method: .post, path: "/images/upload-url"))

        #expect(response.statusCode == 500)
        #expect(await spy.recorded().count == 1)
    }
}

private actor ImageUploadControllerSpy: ImageUploadControllerProtocol {
    private var seen: [Request] = []
    private let shouldFail: Bool

    init(shouldFail: Bool = false) {
        self.shouldFail = shouldFail
    }

    func post(_ request: Request, next: Handler) async throws -> Response {
        seen.append(request)
        if shouldFail { throw TestError.intentional }
        return try .success()
    }

    func recorded() -> [Request] { seen }
}

struct MaToolAPIRegistrationTests {
    @Test("本番のルーター登録によりヘルスチェックが有効になる")
    func healthEndpointRespondsInProductionApplication() async {
        let request = Application.Request.make(method: .get, path: "/health")

        let response = await MaToolAPI.app.handle(request)

        #expect(response.statusCode == 200)
        #expect(response.body == "{}")
    }

    @Test("本番のルーター登録は未知のパスをNot Foundとする")
    func unregisteredPathIsNotFound() async {
        let request = Application.Request.make(method: .get, path: "/not-registered")

        let response = await MaToolAPI.app.handle(request)

        #expect(response.statusCode == 404)
    }
}
