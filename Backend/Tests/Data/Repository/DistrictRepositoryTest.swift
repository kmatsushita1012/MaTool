import Dependencies
import Shared
import Testing
@testable import Backend

struct DistrictRepositoryTest {
    @Test
    func get_正常_ID検索で1件返す() async throws {
        let district = District.mock(id: "district-1", festivalId: "festival-1")
        var lastCalledIndexName: String?

        let dataStore = DataStoreMock(
            queryHandler: { indexName, _, _, _, _, _ in
                lastCalledIndexName = indexName
                return try encodeForDataStore([Record(district)])
            }
        )
        let subject = make(dataStore: dataStore)

        let result = try await subject.get(id: district.id)

        #expect(result == district)
        #expect(dataStore.queryCallCount == 1)
        #expect(lastCalledIndexName == "index-TYPE")
    }

    @Test
    func put_正常_putして同値を返す() async throws {
        let district = District.mock(id: "district-1", festivalId: "festival-1")
        var lastCalledRecord: Record<District>?

        let dataStore = DataStoreMock(
            putHandler: { item in
                lastCalledRecord = try decodeFromEncodable(item, as: Record<District>.self)
            }
        )
        let subject = make(dataStore: dataStore)

        let result = try await subject.put(id: district.id, item: district)

        #expect(result == district)
        #expect(dataStore.putCallCount == 1)
        #expect(lastCalledRecord?.content == district)
    }

    @Test
    func query_異常_依存エラーを透過() async {
        let dataStore = DataStoreMock(
            queryHandler: { _, _, _, _, _, _ in throw TestError.intentional }
        )
        let subject = make(dataStore: dataStore)

        await #expect(throws: TestError.intentional) {
            _ = try await subject.query(by: "festival-1")
        }
    }
}

private extension DistrictRepositoryTest {
    func make(dataStore: DataStoreMock = .init()) -> DistrictRepository {
        withDependencies {
            $0[DataStoreFactoryKey.self] = { _ in dataStore }
        } operation: {
            DistrictRepository()
        }
    }
}
