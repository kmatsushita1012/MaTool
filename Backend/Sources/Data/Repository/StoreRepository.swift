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
    func updateEditableFields(_ store: Store) async throws -> Store
}

struct StoreRepository: StoreRepositoryProtocol {
    private let store: DataStore
    private let encoder = DynamoDBEncoder()
    private let decoder = DynamoDBDecoder()

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

    func updateEditableFields(_ item: Store) async throws -> Store {
        let key = StoreRecord.keys(id: item.id, festivalId: item.festivalId)
        let dynamoKey = ["pk": try encoder.encodeKey(key.pk), "sk": try encoder.encodeKey(key.sk)]
        let names = [
            "#pk": "pk", "#sk": "sk", "#content": "content", "#ownerId": "owner_id",
            "#name": "name", "#address": "address", "#coordinate": "coordinate",
            "#businessHours": "business_hours", "#description": "description",
            "#ownerPaused": "owner_paused", "#bannerImagePath": "banner_image_path",
            "#interstitialImagePath": "interstitial_image_path", "#updatedAt": "updated_at"
        ]
        let values: [String: DynamoDBAttribute] = [
            ":ownerId": try encoder.encodeValue(item.ownerId),
            ":name": try encoder.encodeValue(item.name),
            ":address": try encoder.encodeValue(item.address),
            ":coordinate": try encoder.encodeValue(item.coordinate),
            ":businessHours": try encoder.encodeValue(item.businessHours),
            ":description": try optionalValue(item.description),
            ":ownerPaused": try encoder.encodeValue(item.ownerPaused),
            ":bannerImagePath": try optionalValue(item.bannerImagePath),
            ":interstitialImagePath": try optionalValue(item.interstitialImagePath),
            ":updatedAt": try encoder.encodeValue(item.updatedAt)
        ]
        let update = "SET #content.#name = :name, #content.#address = :address, #content.#coordinate = :coordinate, #content.#businessHours = :businessHours, #content.#description = :description, #content.#ownerPaused = :ownerPaused, #content.#bannerImagePath = :bannerImagePath, #content.#interstitialImagePath = :interstitialImagePath, #content.#updatedAt = :updatedAt"
        let condition = "attribute_exists(#pk) AND attribute_exists(#sk) AND #content.#ownerId = :ownerId"
        guard let attributes = try await store.updateItem(
            keys: dynamoKey,
            updateExpression: update,
            conditionExpression: condition,
            expressionAttributeNames: names,
            expressionAttributeValues: values,
            returnAllNew: true
        ) else { throw Error.internalServerError("Store の更新結果を取得できませんでした。") }
        return try decoder.decode(attributes, as: StoreRecord.self).content
    }

    private func optionalValue<T: Encodable>(_ value: T?) throws -> DynamoDBAttribute {
        guard let value else { return .null(true) }
        return try encoder.encodeValue(value)
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
