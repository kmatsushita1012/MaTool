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
    @Test("危険区間をIDで検索するとTYPEインデックスから取得する")
    func get_正常_危険区間をID検索する() async throws {
        let item = HazardSection.mock(id: "hazard-1", festivalId: "festival-1")
        var index: String?
        let store = DataStoreMock(queryHandler: { indexName, _, _, _, _, _ in
            index = indexName
            return try encodeForDataStore([Record(item)])
        })
        let repository = make(dataStore: store)

        #expect(try await repository.get(id: item.id) == item)
        #expect(store.queryCallCount == 1)
        #expect(index == "index-TYPE")
    }

    @Test("危険区間登録時は返却値と保存レコードを一致させる")
    func post_正常_危険区間を作成する() async throws {
        let item = HazardSection.mock(id: "new-hazard", festivalId: "festival-1")
        var saved: Record<HazardSection>?
        let store = DataStoreMock(putHandler: { record in
            saved = try decodeFromEncodable(record, as: Record<HazardSection>.self)
        })
        let repository = make(dataStore: store)

        #expect(try await repository.post(item) == item)
        #expect(saved?.pk == "FESTIVAL#festival-1")
        #expect(saved?.sk == "HAZARDSECTION#new-hazard")
        #expect(saved?.content == item)
        #expect(store.putCallCount == 1)
    }

    @Test("削除は祭典と危険区間IDに対応する複合キーだけを渡す")
    func delete_正常_PKとSKを渡す() async throws {
        let item = HazardSection.mock(id: "hazard-1", festivalId: "festival-1")
        var keys: [String: Codable] = [:]
        let store = DataStoreMock(deleteHandler: { saved in keys = saved })
        let repository = make(dataStore: store)

        try await repository.delete(item)

        #expect(store.deleteCallCount == 1)
        #expect(keys["pk"] as? String == "FESTIVAL#festival-1")
        #expect(keys["sk"] as? String == "HAZARDSECTION#hazard-1")
    }

    @Test("DIのgetter・setterによりFake Storeを通じた取得が可能")
    func dependencyUsesConfiguredStore() async throws {
        let item = HazardSection.mock(id: "hazard-1", festivalId: "festival-1")
        let store = DataStoreMock(queryHandler: { _, _, _, _, _, _ in
            try encodeForDataStore([Record(item)])
        })
        let repository = withDependencies {
            $0.hazardSectionRepository = make(dataStore: store)
        } operation: {
            @Dependency(\.hazardSectionRepository) var selected
            return selected
        }

        #expect(try await repository.get(id: item.id) == item)
        #expect(store.queryCallCount == 1)
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
