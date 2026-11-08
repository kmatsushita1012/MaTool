import Dependencies
import Shared

enum StoreRepositoryKey: DependencyKey {
    static let liveValue: any StoreRepositoryProtocol = StoreRepository()
}

extension DependencyValues {
    var storeRepository: any StoreRepositoryProtocol {
        get { self[StoreRepositoryKey.self] }
        set { self[StoreRepositoryKey.self] = newValue }
    }
}

protocol StoreRepositoryProtocol: Sendable {
    func get(id: Store.ID, festivalId: Festival.ID, consistentRead: Bool) async throws -> Store?
    func find(id: Store.ID) async throws -> Store?
    func getOwned(id: Store.ID, ownerId: String) async throws -> Store?
    func storesOwned(by ownerId: String) async throws -> [Store]
    func stores(in festivalId: Festival.ID) async throws -> [Store]
    func create(_ store: Store) async throws
    func update(_ store: Store) async throws -> Store
}

struct StoreRepository: StoreRepositoryProtocol {
    private let store: any DynamoDBTransactionalDataStore
    private let encoder = DynamoDBEncoder()

    init() {
        @Dependency(\.dataStoreFactory) var storeFactory
        store = storeFactory("matool")
    }

    func get(id: Store.ID, festivalId: Festival.ID, consistentRead: Bool = true) async throws -> Store? {
        let key = StoreRecord.keys(id: id, festivalId: festivalId)
        return try await store.get(pk: key.pk, sk: key.sk, consistentRead: consistentRead, as: StoreRecord.self)?.content
    }

    func find(id: Store.ID) async throws -> Store? {
        let records = try await store.query(
            indexName: "index-TYPE",
            keyConditions: [
                .equals("type", String(describing: Store.self).uppercased()),
                .equals("sk", "STORE#\(id)")
            ],
            filterConditions: [],
            limit: 1,
            ascending: true,
            as: StoreRecord.self
        )
        return records.first?.content
    }

    func getOwned(id: Store.ID, ownerId: String) async throws -> Store? {
        let refKey = OwnerRecord.keys(ownerId: ownerId, storeId: id)
        guard let reference = try await store.get(pk: refKey.pk, sk: refKey.sk, consistentRead: true, as: OwnerRecord.self)?.content,
              let item = try await get(id: id, festivalId: reference.festivalId, consistentRead: true),
              item.ownerId == ownerId else { return nil }
        return item
    }

    func storesOwned(by ownerId: String) async throws -> [Store] {
        let references = try await store.query(
            indexName: nil,
            keyConditions: [.equals("pk", "USER#\(ownerId)"), .beginsWith("sk", "STORE#")],
            filterConditions: [],
            limit: nil,
            ascending: true,
            consistentRead: true,
            as: OwnerRecord.self
        )
        var stores: [Store] = []
        for reference in references {
            guard let item = try await get(id: reference.content.storeId, festivalId: reference.content.festivalId, consistentRead: true),
                  item.ownerId == ownerId else { continue }
            stores.append(item)
        }
        return stores.sorted { $0.createdAt < $1.createdAt }
    }

    func stores(in festivalId: Festival.ID) async throws -> [Store] {
        try await store.query(
            indexName: nil,
            keyConditions: [.equals("pk", "FESTIVAL#\(festivalId)"), .beginsWith("sk", "STORE#")],
            filterConditions: [],
            limit: nil,
            ascending: true,
            consistentRead: true,
            as: StoreRecord.self
        ).map(\.content)
    }

    func create(_ item: Store) async throws {
        let ownerReference = StoreOwnerReference(storeId: item.id, festivalId: item.festivalId)
        let creditAccount = CreditAccount(storeId: item.id, balance: 0)
        try await store.transactWrite([
            .put(item: try encoder.encode(StoreRecord(item)), conditionExpression: "attribute_not_exists(#pk)", expressionAttributeNames: ["#pk": "pk"], expressionAttributeValues: [:]),
            .put(item: try encoder.encode(OwnerRecord(ownerId: item.ownerId, content: ownerReference)), conditionExpression: "attribute_not_exists(#pk)", expressionAttributeNames: ["#pk": "pk"], expressionAttributeValues: [:]),
            .put(item: try encoder.encode(CreditRecord(creditAccount)), conditionExpression: "attribute_not_exists(#pk)", expressionAttributeNames: ["#pk": "pk"], expressionAttributeValues: [:])
        ])
    }

    func update(_ item: Store) async throws -> Store {
        try await store.put(StoreRecord(item))
        return item
    }
}

private typealias StoreRecord = Record<Store>
private typealias OwnerRecord = Record<StoreOwnerReference>
private typealias CreditRecord = Record<CreditAccount>

private extension Record where Content == Store {
    init(_ content: Store) {
        let key = Self.keys(id: content.id, festivalId: content.festivalId)
        self.init(pk: key.pk, sk: key.sk, content: content)
    }

    static func keys(id: Store.ID, festivalId: Festival.ID) -> (pk: String, sk: String) {
        ("FESTIVAL#\(festivalId)", "STORE#\(id)")
    }
}

private extension Record where Content == StoreOwnerReference {
    init(ownerId: String, content: StoreOwnerReference) {
        let key = Self.keys(ownerId: ownerId, storeId: content.storeId)
        self.init(pk: key.pk, sk: key.sk, content: content)
    }

    static func keys(ownerId: String, storeId: Store.ID) -> (pk: String, sk: String) {
        ("USER#\(ownerId)", "STORE#\(storeId)")
    }
}

private extension Record where Content == CreditAccount {
    init(_ content: CreditAccount) {
        self.init(pk: "STORE#\(content.storeId)", sk: "CREDIT", content: content)
    }
}
