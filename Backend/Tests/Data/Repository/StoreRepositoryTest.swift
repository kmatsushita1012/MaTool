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
