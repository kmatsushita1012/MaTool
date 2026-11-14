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
    @Test("祭典配下のチェックポイント一覧を同じ順序で返す")
    func query_正常_祭典から一覧を取得する() async throws {
        let first = Checkpoint.mock(id: "checkpoint-1", festivalId: "festival-1")
        let second = Checkpoint.mock(id: "checkpoint-2", festivalId: "festival-1")
        var conditions: [QueryCondition] = []
        let store = DataStoreMock(queryHandler: { _, query, _, _, _, _ in
            conditions = query
            return try encodeForDataStore([Record(first), Record(second)])
        })
        let repository = make(dataStore: store)

        let result = try await repository.query(by: "festival-1")

        #expect(result == [first, second])
        #expect(store.queryCallCount == 1)
        #expect(conditions.count == 2)
    }

    @Test("チェックポイント更新は変更後のレコードを正確に保存する")
    func put_正常_チェックポイントを更新する() async throws {
        let item = Checkpoint.mock(id: "checkpoint-1", festivalId: "festival-1")
        var stored: Record<Checkpoint>?
        let store = DataStoreMock(putHandler: { record in
            stored = try decodeFromEncodable(record, as: Record<Checkpoint>.self)
        })
        let repository = make(dataStore: store)

        let result = try await repository.put(item)

        #expect(result == item)
        #expect(stored?.content == item)
        #expect(stored?.pk == "FESTIVAL#festival-1")
        #expect(stored?.sk == "CHECKPOINT#checkpoint-1")
        #expect(store.putCallCount == 1)
    }

    @Test("チェックポイント作成は同じ祭典スコープに追加する")
    func post_正常_チェックポイントを作成する() async throws {
        let item = Checkpoint.mock(id: "new-checkpoint", festivalId: "festival-1")
        var stored: Record<Checkpoint>?
        let store = DataStoreMock(putHandler: { record in
            stored = try decodeFromEncodable(record, as: Record<Checkpoint>.self)
        })
        let repository = make(dataStore: store)

        let result = try await repository.post(item)

        #expect(result == item)
        #expect(stored?.content == item)
        #expect(stored?.sk == "CHECKPOINT#new-checkpoint")
        #expect(store.putCallCount == 1)
    }

    @Test("リポジトリDIのGetterとSetterはテスト用ストアを保持する")
    func dependencyAccessorsPreserveInjectedRepository() async throws {
        let item = Checkpoint.mock(id: "checkpoint", festivalId: "festival")
        let store = DataStoreMock(queryHandler: { _, _, _, _, _, _ in
            try encodeForDataStore([Record(item)])
        })
        let injected = make(dataStore: store)
        let repository = withDependencies {
            $0.checkpointRepository = injected
        } operation: {
            @Dependency(\.checkpointRepository) var dependency
            return dependency
        }

        #expect(try await repository.get(id: item.id) == item)
        #expect(store.queryCallCount == 1)
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
