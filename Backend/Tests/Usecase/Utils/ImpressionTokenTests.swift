import Foundation
import Shared
import Testing
@testable import Backend

struct ImpressionTokenTests {
    @Test("署名済み表示tokenを復号し改ざんと期限切れを拒否する")
    func verifiesSignatureExpiryAndPayload() throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let token = ImpressionToken(secret: String(repeating: "s", count: 32))
        let payload = ImpressionTokenPayload(
            impressionId: "impression-1",
            storeId: "store-1",
            festivalId: "festival-1",
            placement: .banner,
            expiresAt: now.addingTimeInterval(120)
        )
        let signed = try token.sign(payload)

        #expect(try token.verify(signed, now: now) == payload)

        let tampered = String(signed.dropLast()) + (signed.last == "a" ? "b" : "a")
        #expect(throws: Error.self) { try token.verify(tampered, now: now) }
        #expect(throws: Error.self) { try token.verify(signed, now: payload.expiresAt) }
    }

    @Test("短すぎる署名鍵ではtokenを発行しない")
    func rejectsShortSigningSecret() {
        let token = ImpressionToken(secret: "short")
        let payload = ImpressionTokenPayload(
            impressionId: "impression-1",
            storeId: "store-1",
            festivalId: "festival-1",
            placement: .banner,
            expiresAt: .now.addingTimeInterval(120)
        )

        #expect(throws: Error.self) { try token.sign(payload) }
    }
}
