import Foundation
@preconcurrency import AWSDynamoDB
import Testing
@testable import Backend

struct DynamoDBEncoderTests {
    @Test("文字列・数値・真偽値・配列・辞書をDynamoDBのAttributeValueに変換する")
    func encodesNestedJSONAndPrimitiveValues() throws {
        let payload = Sample(
            displayName: "掛川祭",
            count: 12,
            ratio: 2.25,
            enabled: true,
            nested: .init(code: "town", score: 3),
            tags: ["one", "two"],
            indexes: [1, 2],
            empty: []
        )

        let encoded = try DynamoDBEncoder().encode(payload)

        guard case .some(.s(let title)) = encoded["display_name"],
              case .some(.n(let count)) = encoded["count"],
              case .some(.n(let ratio)) = encoded["ratio"],
              case .some(.bool(let flag)) = encoded["enabled"],
              case .some(.m(let nested)) = encoded["nested"],
              case .some(.l(let tags)) = encoded["tags"],
              case .some(.l(let indexes)) = encoded["indexes"],
              case .some(.l(let empty)) = encoded["empty"]
        else {
            Issue.record("必須属性がDynamoDB型に変換されていません")
            return
        }

        #expect(title == "掛川祭")
        #expect(count == "12")
        #expect(Double(ratio) == 2.25)
        #expect(flag)
        #expect(nested["code"] == .s("town"))
        #expect(nested["score"] == .n("3"))
        #expect(tags == [.s("one"), .s("two")])
        #expect(indexes == [.n("1"), .n("2")])
        #expect(empty.isEmpty)
    }

    @Test("明示的なnullをDynamoDBのnullにエンコードする")
    func representsNilAsNull() throws {
        let encoded = try DynamoDBEncoder().encode(ExplicitNull())

        guard case .some(.null(let flag)) = encoded["missing"] else {
            Issue.record("nilがDynamoDB NULLではありません")
            return
        }
        #expect(flag)
    }

    @Test("トップレベルがオブジェクトでないJSONは例外とする")
    func rejectsTopLevelArray() {
        #expect(throws: NSError.self) {
            _ = try DynamoDBEncoder().encode([1, 2, 3])
        }
    }

    @Test("Codableによるエンコードの失敗を伝播する")
    func forwardsEncodingFailure() {
        #expect(throws: TestFailure.self) {
            _ = try DynamoDBEncoder().encode(FailingEncodable())
        }
    }

    @Test("文字列・整数・浮動小数点・真偽値のキー変換を区別する")
    func supportsAllKeyTypes() throws {
        let encoder = DynamoDBEncoder()

        #expect(try encoder.encodeKey("district") == .s("district"))
        #expect(try encoder.encodeKey(-42) == .n("-42"))
        #expect(try encoder.encodeKey(1.5) == .n("1.5"))
        #expect(try encoder.encodeKey(true) == .bool(true))
        #expect(try encoder.encodeKey(false) == .bool(false))
    }

    @Test("サポート外の型は安易に文字列化せずエラーとする")
    func rejectsUnsupportedKeyType() {
        #expect(throws: NSError.self) {
            _ = try DynamoDBEncoder().encodeKey(Date(timeIntervalSince1970: 123))
        }
    }

    @Test("エンコード結果をDynamoDBから元のモデルへ可逆に戻せる")
    func roundTripsThroughDynamoDBDecoder() throws {
        let payload = Sample(
            displayName: "日本語と絵文字🏮",
            count: 0, ratio: -0.5, enabled: false,
            nested: .init(code: "abc", score: -1),
            tags: [], indexes: [10, 20], empty: []
        )

        let encoded = try DynamoDBEncoder().encode(payload)
        let restored = try DynamoDBDecoder().decode(encoded, as: Sample.self)

        #expect(restored == payload)
    }
}

private struct Sample: Codable, Equatable {
    let displayName: String
    let count: Int
    let ratio: Double
    let enabled: Bool
    let nested: Nested
    let tags: [String]
    let indexes: [Int]
    let empty: [Int]

    struct Nested: Codable, Equatable {
        let code: String
        let score: Int
    }
}

private struct ExplicitNull: Encodable {
    enum CodingKeys: String, CodingKey {
        case missing
    }

    func encode(to encoder: Encoder) throws {
        var keyed = encoder.container(keyedBy: CodingKeys.self)
        try keyed.encodeNil(forKey: .missing)
    }
}

private enum TestFailure: Swift.Error {
    case expected
}

private struct FailingEncodable: Encodable {
    func encode(to encoder: Encoder) throws {
        throw TestFailure.expected
    }
}
