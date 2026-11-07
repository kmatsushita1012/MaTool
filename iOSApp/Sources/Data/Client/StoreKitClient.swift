import Dependencies
import Foundation
import StoreKit

struct StoreCreditProduct: Equatable, Sendable, Identifiable {
    let id: String
    let displayName: String
    let description: String
    let displayPrice: String
}

struct StoreKitTransactionInfo: Equatable, Sendable {
    let transactionId: String
    let signedTransactionInfo: String
    let appAccountToken: UUID?
}

enum StoreKitPurchaseOutcome: Equatable, Sendable {
    case purchased(StoreKitTransactionInfo)
    case pending
    case cancelled
}

extension DependencyValues {
    var storeKitClient: any StoreKitClientProtocol {
        get { self[StoreKitClientKey.self] }
        set { self[StoreKitClientKey.self] = newValue }
    }
}

protocol StoreKitClientProtocol: Sendable {
    func products() async throws -> [StoreCreditProduct]
    func purchase(productId: String, appAccountToken: UUID) async throws -> StoreKitPurchaseOutcome
    func unfinishedTransactions() async -> [StoreKitTransactionInfo]
    func finish(transactionId: String) async
}

actor StoreKitClient: StoreKitClientProtocol {
    @Dependency(\.values) private var values
    private var productsById: [String: Product] = [:]
    private var transactionsById: [String: Transaction] = [:]

    func products() async throws -> [StoreCreditProduct] {
        let configuredIds = [values.storeCreditProductId500, values.storeCreditProductId1000]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
        guard !configuredIds.isEmpty else {
            throw AppError.system(.unexpected("クレジット商品の Product ID が設定されていません。"))
        }

        let products = try await Product.products(for: configuredIds)
        productsById = Dictionary(uniqueKeysWithValues: products.map { ($0.id, $0) })
        let order = Dictionary(uniqueKeysWithValues: configuredIds.enumerated().map { ($1, $0) })
        return products
            .map {
                StoreCreditProduct(
                    id: $0.id,
                    displayName: $0.displayName,
                    description: $0.description,
                    displayPrice: $0.displayPrice
                )
            }
            .sorted { (order[$0.id] ?? .max) < (order[$1.id] ?? .max) }
    }

    func purchase(productId: String, appAccountToken: UUID) async throws -> StoreKitPurchaseOutcome {
        guard let product = productsById[productId] else {
            throw AppError.system(.unexpected("購入できる商品が見つかりません。"))
        }

        switch try await product.purchase(options: [.appAccountToken(appAccountToken)]) {
        case .success(let verification):
            guard case .verified(let transaction) = verification else {
                throw AppError.system(.unexpected("StoreKit 取引を検証できませんでした。"))
            }
            transactionsById[String(transaction.id)] = transaction
            return .purchased(Self.info(for: transaction, signedTransactionInfo: verification.jwsRepresentation))
        case .pending:
            return .pending
        case .userCancelled:
            return .cancelled
        @unknown default:
            throw AppError.system(.unexpected("購入状態を確認できませんでした。"))
        }
    }

    func unfinishedTransactions() async -> [StoreKitTransactionInfo] {
        var result: [StoreKitTransactionInfo] = []
        for await verification in Transaction.unfinished {
            guard case .verified(let transaction) = verification else { continue }
            transactionsById[String(transaction.id)] = transaction
            result.append(Self.info(for: transaction, signedTransactionInfo: verification.jwsRepresentation))
        }
        return result
    }

    func finish(transactionId: String) async {
        guard let transaction = transactionsById.removeValue(forKey: transactionId) else { return }
        await transaction.finish()
    }

    private static func info(for transaction: Transaction, signedTransactionInfo: String) -> StoreKitTransactionInfo {
        StoreKitTransactionInfo(
            transactionId: String(transaction.id),
            signedTransactionInfo: signedTransactionInfo,
            appAccountToken: transaction.appAccountToken
        )
    }
}

enum StoreKitClientKey: DependencyKey {
    static let liveValue: any StoreKitClientProtocol = StoreKitClient()
}
