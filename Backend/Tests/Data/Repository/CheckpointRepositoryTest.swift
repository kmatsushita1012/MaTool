import Dependencies
import Shared
import Testing
@testable import Backend

struct CheckpointRepositoryTest {
    @Test
    func get_正常_TYPEインデックスから1件返す() async throws {
        let checkpoint = Checkpoint.mock(id: "checkpoint-1", festivalId: "festival-1")
        var lastCalledIndexName: String?

        let dataStore = DataStoreMock(
            queryHandler: { indexName, _, _, _, _, _ in
                lastCalledIndexName = indexName
                return try encodeForDataStore([Record(checkpoint)])
            }
        )
        let subject = make(dataStore: dataStore)

        let result = try await subject.get(id: checkpoint.id)

        #expect(result == checkpoint)
        #expect(dataStore.queryCallCount == 1)
        #expect(lastCalledIndexName == "index-TYPE")
    }

    @Test
    func delete_正常_pkとskで削除する() async throws {
        let checkpoint = Checkpoint.mock(id: "checkpoint-1", festivalId: "festival-1")
        var lastCalledKeys: [String: Codable] = [:]

        let dataStore = DataStoreMock(
            deleteHandler: { keys in
                lastCalledKeys = keys
            }
        )
        let subject = make(dataStore: dataStore)

        try await subject.delete(checkpoint)

        #expect(dataStore.deleteCallCount == 1)
        #expect((lastCalledKeys["pk"] as? String) == "FESTIVAL#festival-1")
        #expect((lastCalledKeys["sk"] as? String) == "CHECKPOINT#checkpoint-1")
    }

    @Test
    func post_異常_依存エラーを透過() async {
        let dataStore = DataStoreMock(
            putHandler: { _ in throw TestError.intentional }
        )
        let subject = make(dataStore: dataStore)

        await #expect(throws: TestError.intentional) {
            _ = try await subject.post(.mock(id: "checkpoint-1", festivalId: "festival-1"))
        }
    }
}

private extension CheckpointRepositoryTest {
    func make(dataStore: DataStoreMock = .init()) -> CheckpointRepository {
        withDependencies {
            $0[DataStoreFactoryKey.self] = { _ in dataStore }
        } operation: {
            CheckpointRepository()
        }
    }
}
