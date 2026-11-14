import Foundation
import Shared
import Testing
@testable import Backend

struct RequestDecodeTests {
    @Test("有効なJSON本文は指定した型として復号する")
    func decodesValidBody() throws {
        let request = Application.Request.make(
            method: .post,
            path: "/test",
            body: #"{"name":"祭","count":3}"#
        )

        let payload = try request.body(as: Payload.self)

        #expect(payload.name == "祭")
        #expect(payload.count == 3)
    }

    @Test("本文が未指定の場合は400のbadRequestとして扱う")
    func missingBodyIsBadRequest() {
        let request = Application.Request.make(method: .post, path: "/test")

        do {
            _ = try request.body(as: Payload.self)
            Issue.record("本文が未指定なのにデコードが成功しました")
        } catch let error as Error {
            #expect(error.statusCode == 400)
            #expect(error.localizedDescription == "送信されたデータが不十分です。")
        } catch {
            Issue.record("予期しないエラー: \(error)")
        }
    }

    @Test("本文が不正JSONまたは型違いならデコードエラーを返す")
    func malformedOrMismatchedBodyIsDecodingError() {
        for body in [#"{"name":"only-name"}"#, #"{"name":3,"count":"bad"}"#, "garbage"] {
            let request = Application.Request.make(
                method: .post, path: "/test", body: body
            )
            do {
                _ = try request.body(as: Payload.self)
                Issue.record("不正な本文が受理されました: \(body)")
            } catch let error as Error {
                #expect(error.statusCode == 500)
                #expect(error.localizedDescription == "デコードに失敗しました。")
            } catch {
                Issue.record("予期しないエラー: \(error)")
            }
        }
    }

    @Test("ルートパラメータは指定された型に変換する")
    func parsesParametersAsRequestedTypes() throws {
        let request = Application.Request.make(
            method: .get, path: "/test",
            parameters: ["year": "2026", "id": "district"]
        )

        #expect(try request.parameter("year", as: Int.self) == 2026)
        #expect(try request.parameter("id", as: String.self) == "district")
    }

    @Test("欠落・型変換できないパラメータはbadRequestになる")
    func invalidParametersAreBadRequest() {
        let request = Application.Request.make(
            method: .get, path: "/test",
            parameters: ["year": "not-a-number"]
        )
        for key in ["year", "missing"] {
            do {
                _ = try request.parameter(key, as: Int.self)
                Issue.record("不正なパラメータが受理されました: \(key)")
            } catch let error as Error {
                #expect(error.statusCode == 400)
                #expect(error.localizedDescription == "送信されたデータが不十分です。")
            } catch {
                Issue.record("予期しないエラー: \(error)")
            }
        }
    }
}

private struct Payload: Codable {
    let name: String
    let count: Int
}
