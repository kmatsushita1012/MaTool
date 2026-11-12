import Foundation
import Shared
import Testing
@testable import Backend

struct ResponseEncodeTests {
    @Test("成功レスポンスはJSON本文、200、Content-Typeを持つ")
    func encodesSuccessResponse() throws {
        let response = try Application.Response.success(Payload(name: "掛川祭", count: 2))
        let decoded = try Payload.from(response.body)

        #expect(response.statusCode == 200)
        #expect(response.headers["Content-Type"] == "application/json")
        #expect(decoded.name == "掛川祭")
        #expect(decoded.count == 2)
    }

    @Test("空の成功レスポンスは有効な空JSONオブジェクトを持つ")
    func successWithoutPayloadIsEmptyJSONObject() throws {
        let response = try Application.Response.success()

        #expect(response.statusCode == 200)
        #expect(response.headers["Content-Type"] == "application/json")
        #expect(response.body == "{}")
    }

    @Test("エンコードに失敗したら成功レスポンスにせずエラーを返す")
    func encodingFailureIsNotSilenced() {
        do {
            _ = try Application.Response.success(FailingEncodable())
            Issue.record("不正なモデルのエンコードが成功しました")
        } catch let error as Error {
            #expect(error.statusCode == 500)
            #expect(error.localizedDescription == "エンコードに失敗しました。")
        } catch {
            Issue.record("予期しないエラー: \(error)")
        }
    }

    @Test("アプリケーションの認可失敗は403と詳細メッセージに変換する")
    func mapsKnownErrorsToHTTP() throws {
        let response = Application.Response.error(Error.forbidden("権限がありません"))
        let body = try ErrorResponse.from(response.body)

        #expect(response.statusCode == 403)
        #expect(response.headers["Content-Type"] == "application/json")
        #expect(body.message == "権限がありません")
        #expect(body.localizedDescription == "権限がありません")
    }

    @Test("未知のエラーは内部詳細を漏らさず汎用500を返す")
    func hidesUnknownErrors() throws {
        let response = Application.Response.error(Failure.privateError)
        let body = try ErrorResponse.from(response.body)

        #expect(response.statusCode == 500)
        #expect(response.headers["Content-Type"] == "application/json")
        #expect(body.message == "Internal Server Error")
        #expect(body.localizedDescription == "予期しないエラーが発生しました。")
    }
}

private struct Payload: Codable {
    let name: String
    let count: Int
}

private enum Failure: Swift.Error {
    case privateError
}

private struct FailingEncodable: Encodable {
    func encode(to encoder: Encoder) throws {
        throw Failure.privateError
    }
}
