import Foundation
import Testing
@testable import Backend

struct CoderTests {
    @Test("日本語と秒単位のDateをJSONとして往復できる")
    func roundTripsDateAndUnicode() throws {
        let value = Payload(
            title: "掛川祭",
            timestamp: Date(timeIntervalSince1970: 1_700_000_000),
            count: 0
        )

        let json = try value.toString()
        let decoded = try Payload.from(json)
        let object = try #require(JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any])

        #expect(decoded == value)
        #expect(object["title"] as? String == "掛川祭")
        #expect(object["timestamp"] as? Double == 1_700_000_000)
        #expect(object["count"] as? Int == 0)
    }

    @Test("不正なJSONは復号に失敗し、暗黙のデフォルト値を作らない")
    func rejectsMalformedJSON() {
        #expect(throws: DecodingError.self) {
            try Payload.from("{\"title\":")
        }
        #expect(throws: DecodingError.self) {
            try Payload.from("{\"title\":\"test\",\"timestamp\":\"invalid\",\"count\":1}")
        }
    }

    @Test("Encodableがエラーを返した場合、そのエラーを伝播する")
    func propagatesEncodingFailure() {
        #expect(throws: DeliberateFailure.self) {
            try FailingEncodable().toString()
        }
    }

    @Test("文字列変換では有効値を採用し、不正値を拒否する")
    func convertsLosslessValues() throws {
        #expect(try NonCodableIdentifier.from("district-1").description == "district-1")
        #expect(throws: Error.self) {
            try NonCodableIdentifier.from("")
        }
        #expect(throws: Error.self) {
            try NonCodableIdentifier.from("with space")
        }
    }
}

private struct Payload: Codable, Equatable {
    let title: String
    let timestamp: Date
    let count: Int
}

private enum DeliberateFailure: Swift.Error {
    case expected
}

private struct FailingEncodable: Encodable {
    func encode(to encoder: Encoder) throws {
        throw DeliberateFailure.expected
    }
}

private struct NonCodableIdentifier: LosslessStringConvertible {
    let description: String

    init?(_ description: String) {
        guard !description.isEmpty,
              description.allSatisfy({ $0.isASCII && !$0.isWhitespace }) else { return nil }
        self.description = description
    }
}
