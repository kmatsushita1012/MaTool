import Testing
import Dependencies
@testable import Backend
import Shared
import Foundation

struct ProgramRepositoryTests {
    let expected = Program(festivalId: "fes_1", year: 2025, periods: [])

    @Test
    func test_get_正常() async throws {
        let store = DataStoreMock<String, Program>(response: expected)
        let repo = make(dataStore: store)
        let result = try await repo.get(festivalId: "fes_1", year: 2025)
        #expect(result == expected)
        #expect(store.getCallCount == 1)
    }

    @Test
    func test_query_正常() async throws {
        let store = DataStoreMock<String, Program>(response: expected)
        let repo = make(dataStore: store)
        let result = try await repo.query(by: "fes_1")
        #expect(result == [expected])
        #expect(store.queryCallCount == 1)
    }

    @Test
    func test_post_正常() async throws {
        let store = DataStoreMock<String, Program>(response: expected)
        let repo = make(dataStore: store)
        let result = try await repo.post(expected)
        #expect(result == expected)
        #expect(store.putCallCount == 1)
    }

    @Test
    func test_put_正常() async throws {
        let store = DataStoreMock<String, Program>(response: expected)
        let repo = make(dataStore: store)
        let result = try await repo.put(expected)
        #expect(result == expected)
        #expect(store.putCallCount == 1)
    }

    @Test
    func test_delete_正常() async throws {
        let store = DataStoreMock<String, Program>(response: expected)
        let repo = make(dataStore: store)
        try await repo.delete(festivalId: "fes_1", year: 2025)
        #expect(store.deleteCallCount == 1)
    }
}

// MARK: - SUT Factory
private extension ProgramRepositoryTests {
    func make(dataStore: DataStoreMock<String, Program> = .init(response: .init(festivalId: "f-id", year: 2025, periods: []))) -> ProgramRepository {
        let subject = withDependencies({
            $0.dataStoreFactory = { _ in dataStore }
        }) {
            ProgramRepository()
        }
        return subject
    }
}
