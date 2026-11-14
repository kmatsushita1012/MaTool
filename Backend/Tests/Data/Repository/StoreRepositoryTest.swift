import Dependencies
import Foundation
import Shared
import Testing
@testable import Backend

struct StoreRepositoryTest {
    @Test("公開店舗 query は停止状態を即時反映する強整合読取を使う")
    func storesInUsesStrongConsistentRead() async throws {
        let store = makeStore()
        let encoded = try JSONEncoder().encode([Record(pk: "FESTIVAL#festival-1", sk: "STORE#store-1", content: store)])
        let dataStore = DataStoreMock(consistentQueryHandler: { _, _, _, _, _, consistentRead, _ in
            #expect(consistentRead)
            return encoded
        })

        let result = try await withDependencies {
            $0.dataStoreFactory = { _ in dataStore }
        } operation: {
            try await StoreRepository().stores(in: store.festivalId)
        }

        #expect(result == [store])
        #expect(dataStore.lastQueryConsistentRead == true)
    }

    @Test("Store 更新は DataStore の put に委譲する")
    func updateUsesDataStorePut() async throws {
        let updated = makeStore(bannerImagePath: "https://cdn.example/new.jpg")
        let dataStore = DataStoreMock(putHandler: { _ in })

        let result = try await withDependencies {
            $0.dataStoreFactory = { _ in dataStore }
        } operation: {
            try await StoreRepository().update(updated)
        }

        #expect(result == updated)
        #expect(dataStore.putCallCount == 1)
    }

    @Test("Store 更新は nullable な location を含めて DataStore の put に渡す")
    func updatePassesNullableLocationToDataStore() async throws {
        let updated = makeStore(address: nil, coordinate: nil)
        let dataStore = DataStoreMock(putHandler: { item in
            guard let record = item as? Record<Store> else {
                Issue.record("StoreRecord expected")
                return
            }
            let attributes = try DynamoDBEncoder().encode(record)
            guard case .m(let content)? = attributes["content"] else {
                Issue.record("Store content map was missing")
                return
            }
            if case .null(true)? = content["address"] {} else { Issue.record("address must be DynamoDB NULL") }
            if case .null(true)? = content["coordinate"] {} else { Issue.record("coordinate must be DynamoDB NULL") }
        })

        let result = try await withDependencies {
            $0.dataStoreFactory = { _ in dataStore }
        } operation: {
            try await StoreRepository().update(updated)
        }

        #expect(result.address == nil)
        #expect(result.coordinate == nil)
    }

    @Test("旧 DynamoDB Store で欠落した location attributes は nil として復元する")
    func decodesLegacyStoreWithoutLocationAttributes() throws {
        let store = makeStore()
        var attributes = try DynamoDBEncoder().encode(
            Record(pk: "FESTIVAL#festival-1", sk: "STORE#store-1", content: store)
        )
        guard case .m(var content)? = attributes["content"] else {
            Issue.record("encoded Store content map was missing")
            return
        }
        content.removeValue(forKey: "address")
        content.removeValue(forKey: "coordinate")
        attributes["content"] = .m(content)

        let record = try DynamoDBDecoder().decode(attributes, as: Record<Store>.self)

        #expect(record.content.address == nil)
        #expect(record.content.coordinate == nil)
    }
    @Test("店舗IDと祭典IDの組み合わせで正しいキーを強整合取得する")
    func getUsesFestivalAndStoreKeys() async throws {
        let item = makeStore()
        var captured: [String: Codable] = [:]
        let dataStore = DataStoreMock(getHandler: { keys, _ in
            captured = keys
            return try encodeForDataStore(Record(
                pk: "FESTIVAL#festival-1", sk: "STORE#store-1", content: item
            ))
        })

        let result = try await withDependencies {
            $0.dataStoreFactory = { _ in dataStore }
        } operation: {
            try await StoreRepository().get(id: item.id, festivalId: item.festivalId, consistentRead: true)
        }

        #expect(result == item)
        #expect(captured["pk"] as? String == "FESTIVAL#festival-1")
        #expect(captured["sk"] as? String == "STORE#store-1")
    }

    @Test("店舗IDによる検索はTYPE indexにID条件を含めて1件取得する")
    func findUsesStoreTypeIndex() async throws {
        let item = makeStore()
        var observedIndex: String?
        var observedLimit: Int?
        let dataStore = DataStoreMock(queryHandler: { index, conditions, _, limit, _, _ in
            observedIndex = index
            observedLimit = limit
            #expect(conditions.count == 2)
            return try encodeForDataStore([
                Record(pk: "FESTIVAL#festival-1", sk: "STORE#store-1", content: item)
            ])
        })

        let result = try await withDependencies {
            $0.dataStoreFactory = { _ in dataStore }
        } operation: {
            try await StoreRepository().find(id: item.id)
        }

        #expect(result == item)
        #expect(observedIndex == "index-TYPE")
        #expect(observedLimit == 1)
    }

    @Test("所有店舗取得はOwner参照を経由し、所有者IDの一致を確認する")
    func getOwnedChecksReferenceAndOwner() async throws {
        let item = makeStore()
        let reference = StoreOwnerReference(storeId: item.id, festivalId: item.festivalId)
        let dataStore = DataStoreMock(getHandler: { keys, type in
            if type == Record<StoreOwnerReference>.self {
                #expect(keys["pk"] as? String == "USER#owner-1")
                return try encodeForDataStore(Record(
                    pk: "USER#owner-1", sk: "STORE#store-1", content: reference
                ))
            }
            return try encodeForDataStore(Record(
                pk: "FESTIVAL#festival-1", sk: "STORE#store-1", content: item
            ))
        })

        let result = try await withDependencies {
            $0.dataStoreFactory = { _ in dataStore }
        } operation: {
            try await StoreRepository().getOwned(id: item.id, ownerId: item.ownerId)
        }

        #expect(result == item)
        #expect(dataStore.getCallCount == 2)
    }

    @Test("所有店舗一覧はOwner参照から取得し、実店舗を返す")
    func storesOwnedResolvesReferences() async throws {
        let item = makeStore()
        let reference = StoreOwnerReference(storeId: item.id, festivalId: item.festivalId)
        let dataStore = DataStoreMock(
            getHandler: { _, _ in
                try encodeForDataStore(Record(
                    pk: "FESTIVAL#festival-1", sk: "STORE#store-1", content: item
                ))
            },
            consistentQueryHandler: { index, conditions, _, _, _, consistent, type in
                #expect(index == nil)
                #expect(conditions.count == 2)
                #expect(consistent)
                #expect(type == Record<StoreOwnerReference>.self)
                return try encodeForDataStore([
                    Record(pk: "USER#owner-1", sk: "STORE#store-1", content: reference)
                ])
            }
        )

        let owned = try await withDependencies {
            $0.dataStoreFactory = { _ in dataStore }
        } operation: {
            try await StoreRepository().storesOwned(by: item.ownerId)
        }

        #expect(owned == [item])
        #expect(dataStore.lastQueryConsistentRead == true)
    }

    @Test("店舗登録はStore本体・Owner参照・初期Creditを同一トランザクションで保存する")
    func createAtomicallyInsertsStoreReferenceAndCredit() async throws {
        let item = makeStore()
        let dataStore = DataStoreMock(transactWriteHandler: { operations in
            #expect(operations.count == 3)
        })

        try await withDependencies {
            $0.dataStoreFactory = { _ in dataStore }
        } operation: {
            try await StoreRepository().create(item)
        }

        let writes = try #require(dataStore.lastTransaction)
        #expect(writes.count == 3)
        for write in writes {
            guard case let .put(_, condition, _, _) = write else {
                Issue.record("店舗登録が条件付きPutではありません")
                continue
            }
            #expect(condition == "attribute_not_exists(#pk)")
        }
    }


}

private func makeStore(
    address: String? = "Address",
    coordinate: Coordinate? = Coordinate(latitude: 35, longitude: 139),
    bannerImagePath: String? = "https://cdn.example/old.jpg"
) -> Store {
    Store(
        id: "store-1",
        festivalId: "festival-1",
        ownerId: "owner-1",
        purchaseAccountToken: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
        name: "Store",
        address: address,
        coordinate: coordinate,
        businessHours: "",
        bannerImagePath: bannerImagePath
    )
}
