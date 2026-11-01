import AppStoreServerLibrary
import Dependencies
import Foundation
import Shared

enum AppStoreClientKey: DependencyKey {
    static let liveValue: any AppStoreClientProtocol = AppStoreClient()
}

extension DependencyValues {
    var appStoreClient: any AppStoreClientProtocol {
        get { self[AppStoreClientKey.self] }
        set { self[AppStoreClientKey.self] = newValue }
    }
}

protocol AppStoreClientProtocol: Sendable {
    func verifyPurchase(signedTransactionInfo: String) async throws -> VerifiedPurchase
    func currentPurchase(transactionId: String, environment: String) async throws -> VerifiedPurchase
    func verifyNotification(signedPayload: String) async throws -> VerifiedPurchaseNotification
}

struct VerifiedPurchase: Sendable, Equatable {
    let transactionId: String
    let appAccountToken: UUID
    let productId: String
    let purchasedAt: Date
    let environment: String
    let revocationDate: Date?
    let isConsumable: Bool
}

enum VerifiedPurchaseNotificationType: Sendable, Equatable {
    case refund
    case refundReversed
    case other
}

struct VerifiedPurchaseNotification: Sendable, Equatable {
    let notificationUUID: String?
    let type: VerifiedPurchaseNotificationType
    let signedDate: Date
    let purchase: VerifiedPurchase?
}

struct AppStoreClient: AppStoreClientProtocol {
    @Dependency(\.advertisingEnvironment) private var advertisingEnvironment

    func verifyPurchase(signedTransactionInfo: String) async throws -> VerifiedPurchase {
        let verifier = try makeVerifier()
        let decoded: JWSTransactionDecodedPayload
        switch await verifier.verifyAndDecodeTransaction(signedTransaction: signedTransactionInfo) {
        case .valid(let transaction): decoded = transaction
        case .invalid: throw Error.badRequest("Apple の購入署名を検証できませんでした。")
        }
        let purchase = try verifiedPurchase(from: decoded)
        guard purchase.isConsumable, decoded.quantity == 1, purchase.revocationDate == nil else {
            throw Error.badRequest("購入取引の内容が不正です。")
        }
        return purchase
    }

    func currentPurchase(transactionId: String, environment: String) async throws -> VerifiedPurchase {
        let config = advertisingEnvironment
        guard environment == config.appStoreEnvironment.rawValue else {
            throw Error.badRequest("購入取引の環境が一致しません。")
        }
        let apiClient = try makeAppStoreServerAPIClient(environment: config.appStoreEnvironment, config: config)
        let result = await apiClient.getTransactionInfo(transactionId: transactionId)
        guard case .success(let response) = result,
              let signedTransactionInfo = response.signedTransactionInfo else {
            throw Error.internalServerError("Apple から現在の購入状態を取得できませんでした。")
        }

        let verifier = try makeVerifier()
        let decoded: JWSTransactionDecodedPayload
        switch await verifier.verifyAndDecodeTransaction(signedTransaction: signedTransactionInfo) {
        case .valid(let transaction): decoded = transaction
        case .invalid: throw Error.internalServerError("Apple の現在の購入情報を検証できませんでした。")
        }
        let purchase = try verifiedPurchase(from: decoded)
        guard purchase.transactionId == transactionId,
              purchase.environment == environment,
              purchase.isConsumable,
              decoded.quantity == 1 else {
            throw Error.conflict("Apple の現在の取引情報が購入情報と一致しません。")
        }
        return purchase
    }

    func verifyNotification(signedPayload: String) async throws -> VerifiedPurchaseNotification {
        let verifier = try makeVerifier()
        let notification: ResponseBodyV2DecodedPayload
        switch await verifier.verifyAndDecodeNotification(signedPayload: signedPayload) {
        case .valid(let decoded): notification = decoded
        case .invalid: throw Error.badRequest("Apple の通知署名を検証できませんでした。")
        }
        guard let signedDate = notification.signedDate,
              let notificationType = notification.notificationType else {
            throw Error.badRequest("Apple 通知の内容が不正です。")
        }

        let type: VerifiedPurchaseNotificationType
        switch notificationType {
        case .refund: type = .refund
        case .refundReversed: type = .refundReversed
        default: type = .other
        }
        guard type != .other else {
            return VerifiedPurchaseNotification(
                notificationUUID: notification.notificationUUID,
                type: .other,
                signedDate: signedDate,
                purchase: nil
            )
        }

        guard let signedTransaction = notification.data?.signedTransactionInfo else {
            throw Error.badRequest("Apple 通知に取引情報がありません。")
        }
        let purchase: VerifiedPurchase
        switch await verifier.verifyAndDecodeTransaction(signedTransaction: signedTransaction) {
        case .valid(let transaction):
            let config = advertisingEnvironment
            guard let productId = transaction.productId,
                  config.productCredits[productId] != nil,
                  transaction.type == .consumable,
                  transaction.quantity == 1 else {
                return VerifiedPurchaseNotification(
                    notificationUUID: notification.notificationUUID,
                    type: .other,
                    signedDate: signedDate,
                    purchase: nil
                )
            }
            guard let transactionId = transaction.transactionId, !transactionId.isEmpty,
                  let appAccountToken = transaction.appAccountToken,
                  let purchasedAt = transaction.purchaseDate,
                  transaction.environment != nil else {
                throw Error.badRequest("Apple 通知の取引情報が不完全です。")
            }
            purchase = VerifiedPurchase(
                transactionId: transactionId,
                appAccountToken: appAccountToken,
                productId: productId,
                purchasedAt: purchasedAt,
                environment: transaction.environment?.rawValue ?? "",
                revocationDate: transaction.revocationDate,
                isConsumable: transaction.type == .consumable && transaction.quantity == 1
            )
        case .invalid:
            throw Error.badRequest("Apple 通知内の取引署名を検証できませんでした。")
        }
        return VerifiedPurchaseNotification(
            notificationUUID: notification.notificationUUID,
            type: type,
            signedDate: signedDate,
            purchase: purchase
        )
    }

    private func makeVerifier() throws -> SignedDataVerifier {
        let config = advertisingEnvironment
        guard !config.appStoreBundleId.isEmpty, !config.appleRootCertificates.isEmpty else {
            throw Error.internalServerError("App Store 検証設定が不足しています。")
        }
        return try SignedDataVerifier(
            rootCertificates: config.appleRootCertificates,
            bundleId: config.appStoreBundleId,
            appAppleId: config.appStoreAppId,
            environment: config.appStoreEnvironment,
            enableOnlineChecks: true
        )
    }

    private func verifiedPurchase(from transaction: JWSTransactionDecodedPayload) throws -> VerifiedPurchase {
        guard let transactionId = transaction.transactionId, !transactionId.isEmpty,
              let productId = transaction.productId, !productId.isEmpty,
              let appAccountToken = transaction.appAccountToken,
              let purchasedAt = transaction.purchaseDate,
              let environment = transaction.environment else {
            throw Error.badRequest("購入取引の内容が不正です。")
        }
        return VerifiedPurchase(
            transactionId: transactionId,
            appAccountToken: appAccountToken,
            productId: productId,
            purchasedAt: purchasedAt,
            environment: environment.rawValue,
            revocationDate: transaction.revocationDate,
            isConsumable: transaction.type == .consumable
        )
    }
}

func makeAppStoreServerAPIClient(environment: AppStoreEnvironment, config: AdvertisingEnvironment) throws -> AppStoreServerAPIClient {
    guard !config.appStoreAPIKeyId.isEmpty,
          !config.appStoreAPIIssuerId.isEmpty,
          let keyData = Data(base64Encoded: config.appStoreAPIPrivateKeyBase64),
          let privateKey = String(data: keyData, encoding: .utf8),
          !privateKey.isEmpty else {
        throw Error.internalServerError("App Store Server API の認証設定が不足しています。")
    }
    return try AppStoreServerAPIClient(
        signingKey: privateKey,
        keyId: config.appStoreAPIKeyId,
        issuerId: config.appStoreAPIIssuerId,
        bundleId: config.appStoreBundleId,
        environment: environment
    )
}
