import Dependencies
import Shared
import Testing
@testable import Backend

struct FestivalRepositoryTest {
    @Test
    func get_正常_pkとskで取得する() async throws {
        let festival = Festival.mock(id: "festival-1")
        var lastCalledKeys: [String: Codable] = [:]

        let dataStore = DataStoreMock(
            getHandler: { keys, _ in
                lastCalledKeys = keys
                return try encodeForDataStore(Record(festival))
            }
        )
        let subject = make(dataStore: dataStore)

        let result = try await subject.get(id: festival.id)

        #expect(result == festival)
        #expect(dataStore.getCallCount == 1)
        #expect((lastCalledKeys["pk"] as? String) == "FESTIVAL#\(festival.id)")
        #expect((lastCalledKeys["sk"] as? String) == "METADATA")
    }

    @Test
    func scan_正常_TYPEインデックス検索する() async throws {
        let festival = Festival.mock(id: "festival-1")
        var lastCalledIndexName: String?

        let dataStore = DataStoreMock(
            queryHandler: { indexName, _, _, _, _, _ in
                lastCalledIndexName = indexName
                return try encodeForDataStore([Record(festival)])
            }
        )
        let subject = make(dataStore: dataStore)

        let result = try await subject.scan()

        #expect(result == [festival])
        #expect(dataStore.queryCallCount == 1)
        #expect(lastCalledIndexName == "index-TYPE")
    }

    @Test
    func put_異常_依存エラーを透過() async {
        let dataStore = DataStoreMock(
            putHandler: { _ in throw TestError.intentional }
        )
        let subject = make(dataStore: dataStore)

        await #expect(throws: TestError.intentional) {
            _ = try await subject.put(.mock(id: "festival-1"))
        }
    }
}

private extension FestivalRepositoryTest {
    func make(dataStore: DataStoreMock = .init()) -> FestivalRepository {
        withDependencies {
            $0[DataStoreFactoryKey.self] = { _ in dataStore }
        } operation: {
            FestivalRepository()
        }
    }
}
