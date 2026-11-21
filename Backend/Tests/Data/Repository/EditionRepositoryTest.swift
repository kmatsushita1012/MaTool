import Foundation
import Dependencies
import Shared
import Testing
@testable import Backend

struct EditionRepositoryTest {
    @Test
    func get_IDインデックスでEditionを取得する() async throws {
        let edition = Edition(id: "edition-1", festivalId: "festival-1", year: 2026)
        var indexName: String?
        var conditions: [QueryCondition] = []
        let store = DataStoreMock(queryHandler: { index, keys, _, _, _, _ in
            indexName = index
            conditions = keys
            return try JSONEncoder().encode([EditionRecord(edition)])
        })
        let repository = make(dataStore: store)

        #expect(try await repository.get(id: edition.id) == edition)
        #expect(indexName == "index-type-id")
        #expect(conditions.contains(where: { isEquals($0, field: "type", value: "EDITION") }))
        #expect(conditions.contains(where: { isEquals($0, field: "id", value: edition.id) }))
    }

    @Test
    func get_祭典と年度で主キー検索する() async throws {
        let edition = Edition(id: "edition-1", festivalId: "festival-1", year: 2026)
        var requestedKeys: [String: Codable] = [:]
        let store = DataStoreMock(getHandler: { keys, _ in
            requestedKeys = keys
            return try JSONEncoder().encode(EditionRecord(edition))
        })
        let repository = make(dataStore: store)

        #expect(try await repository.get(festivalId: "festival-1", year: 2026) == edition)
        #expect(requestedKeys["pk"] as? String == "FESTIVAL#festival-1")
        #expect(requestedKeys["sk"] as? String == "EDITION#2026")
    }

    @Test
    func query_祭典配下のEditionを検索する() async throws {
        let edition = Edition(id: "edition-1", festivalId: "festival-1", year: 2026)
        var conditions: [QueryCondition] = []
        let store = DataStoreMock(queryHandler: { _, keys, _, _, _, _ in
            conditions = keys
            return try JSONEncoder().encode([EditionRecord(edition)])
        })
        let repository = make(dataStore: store)

        #expect(try await repository.query(by: "festival-1") == [edition])
        #expect(conditions.contains(where: { isEquals($0, field: "pk", value: "FESTIVAL#festival-1") }))
        #expect(conditions.contains(where: { isBeginsWith($0, field: "sk", prefix: "EDITION#") }))
    }

    @Test
    func post_年度をSKにして保存する() async throws {
        let edition = Edition(id: "edition-1", festivalId: "festival-1", year: 2026)
        var saved: EditionRecord?
        let store = DataStoreMock(putHandler: { saved = try decodeFromEncodable($0, as: EditionRecord.self) })
        let repository = make(dataStore: store)

        #expect(try await repository.post(edition) == edition)
        #expect(saved?.pk == "FESTIVAL#festival-1")
        #expect(saved?.sk == "EDITION#2026")
        #expect(saved?.id == edition.id)
    }
}

private extension EditionRepositoryTest {
    func make(dataStore: DataStoreMock) -> EditionRepository {
        withDependencies {
            $0.dataStoreFactory = { dataStore }
        } operation: {
            EditionRepository()
        }
    }

    func isEquals(_ condition: QueryCondition, field: String, value: String) -> Bool {
        guard case let .equals(actualField, actualValue) = condition,
              let actualValue = actualValue as? String else { return false }
        return actualField == field && actualValue == value
    }

    func isBeginsWith(_ condition: QueryCondition, field: String, prefix: String) -> Bool {
        guard case let .beginsWith(actualField, actualPrefix) = condition else { return false }
        return actualField == field && actualPrefix == prefix
    }
}
