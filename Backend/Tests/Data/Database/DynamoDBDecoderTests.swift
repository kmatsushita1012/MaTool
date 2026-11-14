import Foundation
@preconcurrency import AWSDynamoDB
import Testing
@testable import Backend

struct DynamoDBDecoderTests {
    @Test("DynamoDBの全基本型・ネスト・snake_caseをCodableモデルに復号する")
    func decodesPrimitivesAndNestedValues() throws {
        let values: [String: DynamoDBClientTypes.AttributeValue] = [
            "display_name": .s("掛川祭"),
            "count": .n("12"),
            "ratio": .n("-2.25"),
            "approved": .bool(true),
            "tags": .l([.s("a"), .s("b")]),
            "nested": .m(["total_count": .n("3")]),
            "missing": .null(true)
        ]

        let result = try DynamoDBDecoder().decode(values, as: Model.self)

        #expect(result.displayName == "掛川祭")
        #expect(result.count == 12)
        #expect(result.ratio == -2.25)
        #expect(result.approved)
        #expect(result.tags == ["a", "b"])
        #expect(result.nested.totalCount == 3)
        #expect(result.missing == nil)
    }

    @Test("整数に変換できない数値文字列はDoubleとして扱う")
    func decodesDecimalNumbers() throws {
        let result = try DynamoDBDecoder().decode(
            ["ratio": .n("0.125")],
            as: FloatPayload.self
        )

        #expect(result.ratio == 0.125)
    }

    @Test("数字ではないN属性は文字列のまま保持する")
    func unparseableNPreservesString() throws {
        let result = try DynamoDBDecoder().decode(
            ["value": .n("not-a-number")],
            as: TextPayload.self
        )

        #expect(result.value == "not-a-number")
    }

    @Test("DynamoDBの未対応型はnullとして扱う")
    func unsupportedDynamoDBTypeBecomesNull() throws {
        let result = try DynamoDBDecoder().decode(
            ["value": .ss(["one", "two"])],
            as: OptionalPayload.self
        )

        #expect(result.value == nil)
    }

    @Test("空のItemをデコードするとOptionalにnilが入る")
    func missingOptionalFieldIsNil() throws {
        let result = try DynamoDBDecoder().decode(
            [:], as: OptionalPayload.self
        )

        #expect(result.value == nil)
    }

    @Test("必須プロパティが欠落するとデコード失敗になる")
    func missingRequiredFieldIsRejected() {
        #expect(throws: DecodingError.self) {
            _ = try DynamoDBDecoder().decode(
                ["display_name": .s("only-title")],
                as: Model.self
            )
        }
    }

    @Test("存在するが型が不一致の値を暗黙変換しない")
    func invalidFieldTypeIsRejected() {
        #expect(throws: DecodingError.self) {
            _ = try DynamoDBDecoder().decode(
                ["count": .s("not-a-number")],
                as: IntegerPayload.self
            )
        }
    }

    @Test("nullの真偽値がfalseの場合でもOptionalはnilとして扱う")
    func nullPayloadIsNil() throws {
        let result = try DynamoDBDecoder().decode(
            ["value": .null(false)],
            as: OptionalPayload.self
        )
        #expect(result.value == nil)
    }
}

private struct Model: Decodable, Equatable {
    let displayName: String
    let count: Int
    let ratio: Double
    let approved: Bool
    let tags: [String]
    let nested: Nested
    let missing: String?

    struct Nested: Decodable, Equatable {
        let totalCount: Int
    }
}

private struct FloatPayload: Decodable {
    let ratio: Double
}

private struct TextPayload: Decodable {
    let value: String
}

private struct OptionalPayload: Decodable {
    let value: String?
}

private struct IntegerPayload: Decodable {
    let count: Int
}
