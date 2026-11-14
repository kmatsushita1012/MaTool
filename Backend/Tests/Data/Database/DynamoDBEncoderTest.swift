import AWSDynamoDB
import Foundation
import Shared
import Testing
@testable import Backend

struct DynamoDBEncoderTest {
    @Test
    func creditAccountLastPurchasedAtUsesSnakeCaseAndRoundTrips() throws {
        let date = Date(timeIntervalSince1970: 1_798_000_000.125)
        let record = Record(pk: "STORE#store-1", sk: "CREDIT", content: CreditAccount(
            storeId: "store-1",
            balance: 500,
            lastPurchasedAt: date
        ))

        let encoded = try DynamoDBEncoder().encode(record)
        guard case let .m(content)? = encoded["content"],
              case .n("500")? = content["balance"],
              case .n? = content["last_purchased_at"] else {
            Issue.record("CreditAccount の DynamoDB 属性名または型が設計と一致しません。")
            return
        }

        let decoded = try DynamoDBDecoder().decode(encoded, as: Record<CreditAccount>.self)
        #expect(decoded.content.balance == 500)
        #expect(decoded.content.lastPurchasedAt == date)
    }

    @Test
    func encodeValueSupportsScalarConditionValues() throws {
        let encoder = DynamoDBEncoder()

        let string = try encoder.encodeValue("NULL")
        let number = try encoder.encodeValue(500)
        let boolean = try encoder.encodeValue(true)

        guard case .s("NULL") = string,
              case .n("500") = number,
              case .bool(true) = boolean else {
            Issue.record("DynamoDB scalar condition values were not encoded with their native types.")
            return
        }
    }
}
