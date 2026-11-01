import Dependencies
import Foundation
import Shared

enum ImpressionChargeResult: Sendable, Equatable {
    case charged
    case alreadyCharged
    case insufficientBalance
}

enum ImpressionRepositoryKey: DependencyKey {
    static let liveValue: any ImpressionRepositoryProtocol = ImpressionRepository()
}

extension DependencyValues {
    var impressionRepository: any ImpressionRepositoryProtocol {
        get { self[ImpressionRepositoryKey.self] }
        set { self[ImpressionRepositoryKey.self] = newValue }
    }
}

protocol ImpressionRepositoryProtocol: Sendable {
    func charge(impressionId: String, storeId: Store.ID, placement: StoreAdPlacement, chargedAt: Date) async throws -> ImpressionChargeResult
}

struct ImpressionRepository: ImpressionRepositoryProtocol {
    private static let recordRetention: TimeInterval = 30 * 24 * 60 * 60
    private let store: any DynamoDBTransactionalDataStore
    private let encoder = DynamoDBEncoder()
    @Dependency(CreditRepositoryKey.self) private var credits

    init() {
        @Dependency(\.dataStoreFactory) var storeFactory
        store = storeFactory("matool")
    }

    func charge(impressionId: String, storeId: Store.ID, placement: StoreAdPlacement, chargedAt: Date) async throws -> ImpressionChargeResult {
        for _ in 0..<5 {
            if try await get(impressionId: impressionId, storeId: storeId) != nil { return .alreadyCharged }
            guard let account = try await credits.get(storeId: storeId) else { throw Error.notFound("Credit 残高が見つかりません。") }
            guard account.balance >= placement.creditCost else { return .insufficientBalance }

            let item = ImpressionRecord(
                impressionId: impressionId,
                storeId: storeId,
                placement: placement,
                chargedAmount: placement.creditCost,
                chargedAt: chargedAt
            )
            let write = DynamoDBTransactionOperation.put(
                item: try encoder.encode(ImpressionDBRecord(
                    item,
                    expiresAt: Int64(chargedAt.addingTimeInterval(Self.recordRetention).timeIntervalSince1970)
                )),
                conditionExpression: "attribute_not_exists(#pk)",
                expressionAttributeNames: ["#pk": "pk"],
                expressionAttributeValues: [:]
            )
            let balanceWrite = try CreditRepository.balanceUpdate(
                storeId: storeId,
                expected: account,
                newBalance: account.balance - placement.creditCost,
                newLastPurchasedAt: nil
            )
            do {
                try await store.transactWrite([write, balanceWrite])
                return .charged
            } catch {
                if try await get(impressionId: impressionId, storeId: storeId) != nil { return .alreadyCharged }
                guard let latest = try await credits.get(storeId: storeId) else { throw error }
                if latest == account { throw error }
            }
        }
        throw Error.conflict("表示実績と残高が競合しました。")
    }

    private func get(impressionId: String, storeId: Store.ID) async throws -> ImpressionRecord? {
        try await store.get(
            pk: "STORE#\(storeId)",
            sk: "IMPRESSION#\(impressionId)",
            consistentRead: true,
            as: ImpressionDBRecord.self
        )?.content
    }
}

private struct ImpressionRecord: Entity, Identifiable {
    let impressionId: String
    let storeId: Store.ID
    let placement: StoreAdPlacement
    let chargedAmount: Int
    let chargedAt: Date
    var id: String { impressionId }
}

private struct ImpressionDBRecord: RecordProtocol {
    let pk: String
    let sk: String
    let type: String
    let content: ImpressionRecord
    let expiresAt: Int64

    private enum CodingKeys: String, CodingKey {
        case pk, sk, type, content
        case expiresAt = "expires_at"
    }

    init(_ content: ImpressionRecord, expiresAt: Int64) {
        self.pk = "STORE#\(content.storeId)"
        self.sk = "IMPRESSION#\(content.impressionId)"
        self.type = String(describing: ImpressionRecord.self).uppercased()
        self.content = content
        self.expiresAt = expiresAt
    }
}
