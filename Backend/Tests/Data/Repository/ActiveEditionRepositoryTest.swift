import Foundation
import Dependencies
import Shared
import Testing
@testable import Backend

struct ActiveEditionRepositoryTest {
    @Test
    func get_祭典IDと固定SKで取得する() async throws {
        let activeEdition = ActiveEdition(festivalId: "festival-1", editionId: "edition-1")
        var requestedKeys: [String: Codable] = [:]
        let store = DataStoreMock(getHandler: { keys, _ in
            requestedKeys = keys
            return try JSONEncoder().encode(ActiveEditionRecord(activeEdition))
        })
        let repository = make(dataStore: store)

        #expect(try await repository.get(festivalId: "festival-1") == activeEdition)
        #expect(requestedKeys["pk"] as? String == "FESTIVAL#festival-1")
        #expect(requestedKeys["sk"] as? String == "ACTIVE_EDITION")
    }

    @Test
    func put_有効Edition参照を保存する() async throws {
        let activeEdition = ActiveEdition(festivalId: "festival-1", editionId: "edition-1")
        var saved: ActiveEditionRecord?
        let store = DataStoreMock(putHandler: { saved = try decodeFromEncodable($0, as: ActiveEditionRecord.self) })
        let repository = make(dataStore: store)

        #expect(try await repository.put(activeEdition) == activeEdition)
        #expect(saved?.pk == "FESTIVAL#festival-1")
        #expect(saved?.sk == "ACTIVE_EDITION")
        #expect(saved?.content.editionId == "edition-1")
    }
}

private extension ActiveEditionRepositoryTest {
    func make(dataStore: DataStoreMock) -> ActiveEditionRepository {
        withDependencies {
            $0.dataStoreFactory = { dataStore }
        } operation: {
            ActiveEditionRepository()
        }
    }
}
