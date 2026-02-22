import Dependencies
import Shared
import Testing
@testable import Backend

struct HazardSectionRepositoryTest {
    @Test
    func query_正常_祭典配下を返す() async throws {
        let hazard = HazardSection.mock(id: "hazard-1", festivalId: "festival-1")
        var lastCalledKeyConditions: [QueryCondition] = []

        let dataStore = DataStoreMock(
            queryHandler: { _, keyConditions, _, _, _, _ in
                lastCalledKeyConditions = keyConditions
                return try encodeForDataStore([Record(hazard)])
            }
        )
        let subject = make(dataStore: dataStore)

        let result = try await subject.query(by: "festival-1")

        #expect(result == [hazard])
        #expect(dataStore.queryCallCount == 1)
        #expect(lastCalledKeyConditions.count == 2)
    }

    @Test
    func put_正常_putして同値を返す() async throws {
        let hazard = HazardSection.mock(id: "hazard-1", festivalId: "festival-1")
        var lastCalledRecord: Record<HazardSection>?

        let dataStore = DataStoreMock(
            putHandler: { item in
                lastCalledRecord = try decodeFromEncodable(item, as: Record<HazardSection>.self)
            }
        )
        let subject = make(dataStore: dataStore)

        let result = try await subject.put(hazard)

        #expect(result == hazard)
        #expect(dataStore.putCallCount == 1)
        #expect(lastCalledRecord?.content == hazard)
    }

    @Test
    func get_異常_依存エラーを透過() async {
        let dataStore = DataStoreMock(
            queryHandler: { _, _, _, _, _, _ in throw TestError.intentional }
        )
        let subject = make(dataStore: dataStore)

        await #expect(throws: TestError.intentional) {
            _ = try await subject.get(id: "hazard-1")
        }
    }
}

private extension HazardSectionRepositoryTest {
    func make(dataStore: DataStoreMock = .init()) -> HazardSectionRepository {
        withDependencies {
            $0[DataStoreFactoryKey.self] = { _ in dataStore }
        } operation: {
            HazardSectionRepository()
        }
    }
}
