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
    @Test("祭典IDによる地区一覧取得は対応するレコードだけを返す")
    func query_正常_祭典配下の地区を返す() async throws {
        let first = District.mock(id: "district-1", festivalId: "festival-1")
        let second = District.mock(id: "district-2", festivalId: "festival-1")
        var seenConditions: [QueryCondition] = []
        let store = DataStoreMock(queryHandler: { _, conditions, _, _, _, _ in
            seenConditions = conditions
            return try encodeForDataStore([Record(first), Record(second)])
        })
        let subject = make(dataStore: store)

        let result = try await subject.query(by: "festival-1")

        #expect(result == [first, second])
        #expect(store.queryCallCount == 1)
        #expect(seenConditions.count == 2)
    }

    @Test("地区の新規登録はPK・SKを含むレコードを保存する")
    func post_正常_新規地区を登録する() async throws {
        let district = District.mock(id: "district-1", festivalId: "festival-1")
        var recorded: Record<District>?
        let store = DataStoreMock(putHandler: { item in
            recorded = try decodeFromEncodable(item, as: Record<District>.self)
        })
        let subject = make(dataStore: store)

        let response = try await subject.post(item: district)

        #expect(response == district)
        #expect(recorded?.pk == "FESTIVAL#festival-1")
        #expect(recorded?.sk == "DISTRICT#district-1")
        #expect(store.putCallCount == 1)
    }

    @Test("DIのGetterとSetterが同一リポジトリを返す")
    func dependencyAccessorUsesInjectedStore() async throws {
        let district = District.mock(id: "district-1", festivalId: "festival-1")
        let store = DataStoreMock(queryHandler: { _, _, _, _, _, _ in
            try encodeForDataStore([Record(district)])
        })
        let subject = make(dataStore: store)
        let dependency = withDependencies {
            $0.districtRepository = subject
        } operation: {
            @Dependency(\.districtRepository) var repository
            return repository
        }

        #expect(try await dependency.get(id: district.id) == district)
        #expect(store.queryCallCount == 1)
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
