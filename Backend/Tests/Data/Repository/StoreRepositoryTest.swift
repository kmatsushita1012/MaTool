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

    @Test("画像変更の更新は moderation_status が approved の場合だけ成功する条件を付ける")
    func imageUpdateRequiresApprovedStatusInConditionExpression() async throws {
        let updated = makeStore(bannerImagePath: "https://cdn.example/new.jpg")
        let encoded = try DynamoDBEncoder().encode(Record(pk: "FESTIVAL#festival-1", sk: "STORE#store-1", content: updated))
        let dataStore = DataStoreMock(updateItemHandler: { _, _, _, names, _, _ in
            #expect(names["#moderationStatus"] == "moderation_status")
            return encoded
        })

        let result = try await withDependencies {
            $0.dataStoreFactory = { _ in dataStore }
        } operation: {
            try await StoreRepository().updateEditableFields(updated, requireApproved: true)
        }

        #expect(result == updated)
        #expect(dataStore.lastUpdateConditionExpression?.contains("#content.#moderationStatus = :approved") == true)
    }

    @Test("DynamoDB の Store location attributes は nil を NULL として保存する")
    func updateStoresNullableLocationAsNull() async throws {
        let updated = makeStore(address: nil, coordinate: nil)
        let encoded = try DynamoDBEncoder().encode(Record(pk: "FESTIVAL#festival-1", sk: "STORE#store-1", content: updated))
        let dataStore = DataStoreMock(updateItemHandler: { _, _, _, _, values, _ in
            if case .null(true) = values[":address"] {} else { Issue.record("address must be DynamoDB NULL") }
            if case .null(true) = values[":coordinate"] {} else { Issue.record("coordinate must be DynamoDB NULL") }
            return encoded
        })

        let result = try await withDependencies {
            $0.dataStoreFactory = { _ in dataStore }
        } operation: {
            try await StoreRepository().updateEditableFields(updated, requireApproved: false)
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
