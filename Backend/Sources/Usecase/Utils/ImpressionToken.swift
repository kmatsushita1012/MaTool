import Crypto
import Foundation
import Shared

struct ImpressionTokenPayload: Codable, Sendable, Equatable {
    let impressionId: String
    let storeId: Store.ID
    let festivalId: Festival.ID
    let placement: StoreAdPlacement
    let expiresAt: Date
}

struct ImpressionToken: Sendable {
    private let secret: String

    init(secret: String = AdvertisingEnvironment().impressionTokenSecret) {
        self.secret = secret
    }

    func sign(_ payload: ImpressionTokenPayload) throws -> String {
        guard secret.utf8.count >= 32 else {
            throw Error.internalServerError("広告表示 token の署名鍵が未設定または短すぎます。")
        }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        let payloadData = try encoder.encode(payload)
        let payloadPart = payloadData.base64URLEncodedString()
        let key = SymmetricKey(data: Data(secret.utf8))
        let signature = HMAC<SHA256>.authenticationCode(for: Data(payloadPart.utf8), using: key)
        return "\(payloadPart).\(Data(signature).base64URLEncodedString())"
    }

    func verify(_ token: String, now: Date = .now) throws -> ImpressionTokenPayload {
        guard secret.utf8.count >= 32 else {
            throw Error.internalServerError("広告表示 token の署名鍵が未設定または短すぎます。")
        }
        let components = token.split(separator: ".", omittingEmptySubsequences: false)
        guard components.count == 2,
              let signature = Data(base64URLString: String(components[1])) else {
            throw Error.badRequest("広告表示 token が不正です。")
        }
        let payloadPart = String(components[0])
        let key = SymmetricKey(data: Data(secret.utf8))
        guard HMAC<SHA256>.isValidAuthenticationCode(signature, authenticating: Data(payloadPart.utf8), using: key),
              let payloadData = Data(base64URLString: payloadPart),
              let payload = try? JSONDecoder.withUnixDates.decode(ImpressionTokenPayload.self, from: payloadData),
              payload.expiresAt > now else {
            throw Error.badRequest("広告表示 token が無効または期限切れです。")
        }
        return payload
    }
}

private extension Data {
    func base64URLEncodedString() -> String {
        base64EncodedString().replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    init?(base64URLString: String) {
        var value = base64URLString.replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let remainder = value.count % 4
        if remainder != 0 { value += String(repeating: "=", count: 4 - remainder) }
        self.init(base64Encoded: value)
    }
}

private extension JSONDecoder {
    static var withUnixDates: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        return decoder
    }
}
