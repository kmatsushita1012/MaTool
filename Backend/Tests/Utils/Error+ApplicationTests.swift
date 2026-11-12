import Shared
import Testing
@testable import Backend

struct ApplicationErrorTests {
    @Test("全エラー種別がHTTPステータスとエラー名を正しく返す")
    func mapsAllErrorCases() {
        let cases: [(error: Error, status: Int, name: String)] = [
            (.notFound("missing"), 404, "Not Found"),
            (.badRequest("invalid"), 400, "Bad Request"),
            (.forbidden("denied"), 403, "Forbidden"),
            (.internalServerError("failure"), 500, "Internal Server Error"),
            (.unauthorized("login"), 401, "Unauthorized"),
            (.conflict("duplicate"), 409, "Conflict"),
            (.encodingError("encode"), 500, "Encoding Error"),
            (.decodingError("decode"), 500, "Decoding Error"),
        ]

        for entry in cases {
            #expect(entry.error.statusCode == entry.status)
            #expect(entry.error.message == entry.name)
            #expect(entry.error.localizedDescription != "unknown")
            #expect(entry.error.response.message == entry.error.localizedDescription)
            #expect(entry.error.response.localizedDescription == entry.error.localizedDescription)
        }
    }

    @Test("メッセージがないエラーではunknownを返す")
    func missingMessageUsesUnknown() {
        let error = Error.notFound(nil)

        #expect(error.localizedDescription == "unknown")
        #expect(error.response.message == "unknown")
        #expect(error.statusCode == 404)
    }

    @Test("全ファクトリーが渡された詳細メッセージを維持する")
    func convenienceFactoriesRetainMessages() {
        let cases: [Error] = [
            .notFound(localizedDescription: "notFound"),
            .badRequest(localizedDescription: "badRequest"),
            .forbidden(localizedDescription: "forbidden"),
            .internalServerError(localizedDescription: "internalServerError"),
            .unauthorized(localizedDescription: "unauthorized"),
            .conflict(localizedDescription: "conflict"),
            .encodingError(localizedDescription: "encodingError"),
            .decodingError(localizedDescription: "decodingError"),
        ]

        #expect(cases.map(\.localizedDescription) == [
            "notFound", "badRequest", "forbidden", "internalServerError",
            "unauthorized", "conflict", "encodingError", "decodingError",
        ])
    }
}
