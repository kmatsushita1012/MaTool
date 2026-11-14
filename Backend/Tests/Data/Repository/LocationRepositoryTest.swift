import Dependencies
import Foundation
import Shared
import Testing
@testable import Backend

struct LocationRepositoryTest {
    @Test
    func get_正常_祭典と地区の完全一致で取得する() async throws {
        let location = FloatLocation.mock(id: "loc-1", districtId: "district-1")
        let dataStore = DataStoreMock(
            queryHandler: { _, keyConditions, _, _, _, _ in
                #expect(keyConditions.count == 2)
                return try encodeForDataStore([Record(location)])
            }
        )
        let subject = make(dataStore: dataStore)

        let result = try await subject.get(festivalId: "festival-1", districtId: "district-1")

        #expect(result == location)
        #expect(dataStore.queryCallCount == 1)
    }

    @Test
    func delete_正常_pkとskで削除する() async throws {
        var lastCalledKeys: [String: Codable] = [:]
        let dataStore = DataStoreMock(
            deleteHandler: { keys in
                lastCalledKeys = keys
            }
        )
        let subject = make(dataStore: dataStore)

        try await subject.delete(festivalId: "festival-1", districtId: "district-1")

        #expect(dataStore.deleteCallCount == 1)
        #expect((lastCalledKeys["pk"] as? String) == "FESTIVAL#festival-1")
        #expect((lastCalledKeys["sk"] as? String) == "LOCATION#DISTRICT#district-1")
    }

    @Test
    func put_異常_依存エラーを透過() async {
        let dataStore = DataStoreMock(
            putHandler: { _ in throw TestError.intentional },
            queryHandler: { _, _, _, _, _, _ in try encodeForDataStore([LRecord]()) }
        )
        let subject = make(dataStore: dataStore)

        await #expect(throws: TestError.intentional) {
            _ = try await subject.put(.mock(id: "loc-1", districtId: "district-1"), festivalId: "festival-1")
        }
    }

    @Test
    func put_正常_既存位置がない場合は保存する() async throws {
        let location = FloatLocation.mock(id: "loc-1", districtId: "district-1")
        let dataStore = DataStoreMock(
            putHandler: { _ in },
            queryHandler: { _, _, _, _, _, _ in try encodeForDataStore([LRecord]()) }
        )
        let subject = make(dataStore: dataStore)

        let result = try await subject.put(location, festivalId: "festival-1")

        #expect(result == location)
        #expect(dataStore.queryCallCount == 1)
        #expect(dataStore.putCallCount == 1)
    }

    @Test
    func put_古いtimestampは保存値を返す() async throws {
        let current = FloatLocation.mock(
            id: "new",
            districtId: "district-1",
            coordinate: .init(latitude: 36, longitude: 140),
            timestamp: Date(timeIntervalSince1970: 200)
        )
        let dataStore = DataStoreMock(queryHandler: { _, _, _, _, _, _ in
            try encodeForDataStore([Record(current)])
        })
        let subject = make(dataStore: dataStore)

        let result = try await subject.put(
            .mock(
                id: "old",
                districtId: "district-1",
                coordinate: .init(latitude: 35, longitude: 139),
                timestamp: Date(timeIntervalSince1970: 100)
            ),
            festivalId: "festival-1"
        )

        #expect(result == current)
        #expect(dataStore.queryCallCount == 1)
        #expect(dataStore.putCallCount == 0)
    }
    @Test("祭典に属する複数地区の位置情報を取得する")
    func query_正常_祭典配下の位置を返す() async throws {
        let first = FloatLocation.mock(id: "one", districtId: "district-1")
        let second = FloatLocation.mock(id: "two", districtId: "district-2")
        var conditions: [QueryCondition] = []
        let store = DataStoreMock(queryHandler: { _, query, _, _, _, _ in
            conditions = query
            return try encodeForDataStore([
                LRecord(first, festivalId: "festival-1"),
                LRecord(second, festivalId: "festival-1")
            ])
        })
        let repository = make(dataStore: store)

        let result = try await repository.query(by: "festival-1")

        #expect(result == [first, second])
        #expect(store.queryCallCount == 1)
        #expect(conditions.count == 2)
    }

    @Test("地区の位置情報投稿は祭典・地区のPKとSKに保存する")
    func post_正常_位置情報を新規登録する() async throws {
        let location = FloatLocation.mock(id: "one", districtId: "district-1")
        var stored: LRecord?
        let store = DataStoreMock(putHandler: { record in
            stored = try decodeFromEncodable(record, as: LRecord.self)
        })
        let repository = make(dataStore: store)

        let result = try await repository.post(location, festivalId: "festival-1")

        #expect(result == location)
        #expect(stored?.pk == "FESTIVAL#festival-1")
        #expect(stored?.sk == "LOCATION#DISTRICT#district-1")
        #expect(stored?.content == location)
        #expect(store.putCallCount == 1)
    }

    @Test("同時刻の再送は新しいリクエストを採用する")
    func put_境界_同じタイムスタンプを更新する() async throws {
        let timestamp = Date(timeIntervalSince1970: 1_700_000_000)
        let previous = FloatLocation.mock(
            id: "previous", districtId: "district-1", timestamp: timestamp
        )
        let current = FloatLocation.mock(
            id: "updated", districtId: "district-1",
            coordinate: .init(latitude: 36, longitude: 140), timestamp: timestamp
        )
        let store = DataStoreMock(
            putHandler: { record in
                let stored = try decodeFromEncodable(record, as: LRecord.self)
                #expect(stored.content == current)
            },
            queryHandler: { _, _, _, _, _, _ in
                try encodeForDataStore([LRecord(previous, festivalId: "festival-1")])
            }
        )
        let repository = make(dataStore: store)

        let result = try await repository.put(current, festivalId: "festival-1")

        #expect(result == current)
        #expect(store.queryCallCount == 1)
        #expect(store.putCallCount == 1)
    }

    @Test("存在しない地区の位置情報はnilを返す")
    func get_異常_位置情報が存在しない() async throws {
        let store = DataStoreMock(queryHandler: { _, _, _, _, _, _ in
            try encodeForDataStore([LRecord]())
        })
        let repository = make(dataStore: store)

        #expect(try await repository.get(festivalId: "festival", districtId: "missing") == nil)
        #expect(store.queryCallCount == 1)
    }

}

private extension LocationRepositoryTest {
    func make(dataStore: DataStoreMock = .init()) -> LocationRepository {
        withDependencies {
            $0[DataStoreFactoryKey.self] = { _ in dataStore }
        } operation: {
            LocationRepository()
        }
    }
}
