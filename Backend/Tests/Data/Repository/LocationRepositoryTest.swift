import Dependencies
import Shared
import Testing
@testable import Backend

struct LocationRepositoryTest {
    @Test
    func get_正常_祭典と地区の完全一致で取得する() async throws {
        let location = FloatLocation.mock(id: "loc-1", districtId: "district-1")
        var lastCalledKeyConditions: [QueryCondition] = []

        let dataStore = DataStoreMock(
            queryHandler: { _, keyConditions, _, _, _, _ in
                lastCalledKeyConditions = keyConditions
                return try encodeForDataStore([Record(location)])
            }
        )
        let subject = make(dataStore: dataStore)

        let result = try await subject.get(festivalId: "festival-1", districtId: "district-1")

        #expect(result == location)
        #expect(dataStore.queryCallCount == 1)
        #expect(lastCalledKeyConditions.count == 2)
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
            putHandler: { _ in throw TestError.intentional }
        )
        let subject = make(dataStore: dataStore)

        await #expect(throws: TestError.intentional) {
            _ = try await subject.put(.mock(id: "loc-1", districtId: "district-1"), festivalId: "festival-1")
        }
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
