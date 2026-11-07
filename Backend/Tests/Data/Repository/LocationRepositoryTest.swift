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
            getHandler: { keys, _ in
                #expect((keys["pk"] as? String) == "FESTIVAL#festival-1")
                #expect((keys["sk"] as? String) == "LOCATION#DISTRICT#district-1")
                return try JSONEncoder().encode(Record(location))
            }
        )
        let subject = make(dataStore: dataStore)

        let result = try await subject.get(festivalId: "festival-1", districtId: "district-1")

        #expect(result == location)
        #expect(dataStore.getCallCount == 1)
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
            putIfNewerHandler: { _, _ in throw TestError.intentional }
        )
        let subject = make(dataStore: dataStore)

        await #expect(throws: TestError.intentional) {
            _ = try await subject.put(.mock(id: "loc-1", districtId: "district-1"), festivalId: "festival-1")
        }
    }

    @Test
    func put_正常_timestamp条件付きで保存する() async throws {
        let location = FloatLocation.mock(id: "loc-1", districtId: "district-1")
        let dataStore = DataStoreMock(putIfNewerHandler: { _, _ in true })
        let subject = make(dataStore: dataStore)

        let result = try await subject.put(location, festivalId: "festival-1")

        #expect(result == location)
        #expect(dataStore.putIfNewerCallCount == 1)
        #expect(dataStore.lastPutIfNewerPath == ["content", "timestamp"])
    }

    @Test
    func put_古いtimestampは保存値を返す() async throws {
        let current = FloatLocation.mock(
            id: "new",
            districtId: "district-1",
            coordinate: .init(latitude: 36, longitude: 140),
            timestamp: Date(timeIntervalSince1970: 200)
        )
        let dataStore = DataStoreMock(
            putIfNewerHandler: { _, _ in false },
            getHandler: { _, _ in try JSONEncoder().encode(Record(current)) }
        )
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
        #expect(dataStore.putIfNewerCallCount == 1)
        #expect(dataStore.getCallCount == 1)
        #expect(dataStore.putCallCount == 0)
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
