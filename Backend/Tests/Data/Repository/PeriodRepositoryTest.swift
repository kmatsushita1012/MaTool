import Foundation
import Dependencies
import Shared
import Testing
@testable import Backend

struct PeriodRepositoryTest {
    @Test
    func get_IDインデックスで期間を取得する() async throws {
        let period = Period.mock(id: "period-1", festivalId: "festival-1", editionId: "edition-1")
        var indexName: String?
        var conditions: [QueryCondition] = []
        let store = DataStoreMock(queryHandler: { index, keys, _, _, _, _ in
            indexName = index
            conditions = keys
            return try JSONEncoder().encode([PeriodRecord(period)])
        })
        let repository = make(dataStore: store)

        #expect(try await repository.get(id: period.id) == period)
        #expect(indexName == "index-type-id")
        #expect(conditions.contains(where: { isEquals($0, field: "type", value: "PERIOD") }))
        #expect(conditions.contains(where: { isEquals($0, field: "id", value: period.id) }))
    }

    @Test
    func query_Edition配下の期間を取得する() async throws {
        let period = Period.mock(id: "period-1", festivalId: "festival-1", editionId: "edition-1")
        var conditions: [QueryCondition] = []
        let store = DataStoreMock(queryHandler: { _, keys, _, _, _, _ in
            conditions = keys
            return try JSONEncoder().encode([PeriodRecord(period)])
        })
        let repository = make(dataStore: store)

        #expect(try await repository.query(byEditionId: "edition-1") == [period])
        #expect(conditions.contains(where: { isEquals($0, field: "pk", value: "EDITION#edition-1") }))
        #expect(conditions.contains(where: { isBeginsWith($0, field: "sk", prefix: "PERIOD#") }))
    }

    @Test
    func query_祭典と年度からEdition経由で期間を取得する() async throws {
        let period = Period.mock(id: "period-1", festivalId: "festival-1", editionId: "edition-1")
        var getKeys: [String: Codable] = [:]
        var queryConditions: [QueryCondition] = []
        let store = DataStoreMock(
            getHandler: { keys, type in
                getKeys = keys
                return try JSONEncoder().encode(EditionRecord(.init(id: "edition-1", festivalId: "festival-1", year: 2026)))
            },
            queryHandler: { _, keys, _, _, _, _ in
                queryConditions = keys
                return try JSONEncoder().encode([PeriodRecord(period)])
            }
        )
        let repository = make(dataStore: store)

        #expect(try await repository.query(by: "festival-1", year: 2026) == [period])
        #expect(getKeys["pk"] as? String == "FESTIVAL#festival-1")
        #expect(getKeys["sk"] as? String == "EDITION#2026")
        #expect(queryConditions.contains(where: { isEquals($0, field: "pk", value: "EDITION#edition-1") }))
    }

    @Test
    func post_新しいキーで保存する() async throws {
        let period = Period.mock(id: "period-1", festivalId: "festival-1", editionId: "edition-1")
        var saved: PeriodRecord?
        let store = DataStoreMock(putHandler: { item in
            saved = try decodeFromEncodable(item, as: PeriodRecord.self)
        })
        let repository = make(dataStore: store)

        #expect(try await repository.post(period) == period)
        #expect(saved?.pk == "EDITION#edition-1")
        #expect(saved?.sk == "PERIOD#period-1")
        #expect(saved?.id == period.id)
        #expect(saved?.content == period)
    }

    @Test
    func post_Edition未設定の期間を拒否する() async {
        let period = Period(id: "period-1", festivalId: "festival-1", date: .init(year: 2026, month: 2, day: 22))
        let repository = make(dataStore: .init())

        await #expect(throws: Error.badRequest("日程にEditionが設定されていません。")) {
            _ = try await repository.post(period)
        }
    }

    @Test
    func put_日時変更ではキーを移動しない() async throws {
        let existing = Period.mock(
            id: "period-1",
            festivalId: "festival-1",
            editionId: "edition-1",
            date: .init(year: 2026, month: 2, day: 22),
            start: .init(hour: 9, minute: 0)
        )
        let updated = Period.mock(
            id: existing.id,
            festivalId: "festival-1",
            editionId: "edition-1",
            date: .init(year: 2027, month: 3, day: 1),
            start: .init(hour: 12, minute: 30)
        )
        var saved: PeriodRecord?
        let store = DataStoreMock(
            putHandler: { item in saved = try decodeFromEncodable(item, as: PeriodRecord.self) },
            queryHandler: { _, _, _, _, _, _ in try JSONEncoder().encode([PeriodRecord(existing)]) }
        )
        let repository = make(dataStore: store)

        #expect(try await repository.put(updated) == updated)
        #expect(saved?.pk == "EDITION#edition-1")
        #expect(saved?.sk == "PERIOD#period-1")
        #expect(store.deleteCallCount == 0)
    }

    @Test
    func put_Edition変更時は旧キーを削除して保存する() async throws {
        let existing = Period.mock(id: "period-1", festivalId: "festival-1", editionId: "edition-old")
        let updated = Period.mock(id: existing.id, festivalId: "festival-1", editionId: "edition-new")
        var deleted: [String: Codable] = [:]
        let store = DataStoreMock(
            putHandler: { _ in },
            deleteHandler: { deleted = $0 },
            queryHandler: { _, _, _, _, _, _ in try JSONEncoder().encode([PeriodRecord(existing)]) }
        )
        let repository = make(dataStore: store)

        _ = try await repository.put(updated)

        #expect(deleted["pk"] as? String == "EDITION#edition-old")
        #expect(deleted["sk"] as? String == "PERIOD#period-1")
    }

    @Test
    func delete_IDインデックスで実際の主キーを削除する() async throws {
        let period = Period.mock(id: "period-1", festivalId: "festival-1", editionId: "edition-1")
        var deleted: [String: Codable] = [:]
        let store = DataStoreMock(
            deleteHandler: { deleted = $0 },
            queryHandler: { _, _, _, _, _, _ in try JSONEncoder().encode([PeriodRecord(period)]) }
        )
        let repository = make(dataStore: store)

        try await repository.delete(id: period.id)

        #expect(deleted["pk"] as? String == "EDITION#edition-1")
        #expect(deleted["sk"] as? String == "PERIOD#period-1")
    }

    @Test
    func query_依存エラーを透過する() async {
        let repository = make(dataStore: .init(queryHandler: { _, _, _, _, _, _ in throw TestError.intentional }))

        await #expect(throws: TestError.intentional) {
            _ = try await repository.query(byEditionId: "edition-1")
        }
    }
}

private extension PeriodRepositoryTest {
    func make(dataStore: DataStoreMock) -> PeriodRepository {
        withDependencies {
            $0.dataStoreFactory = { _ in dataStore }
        } operation: {
            PeriodRepository()
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
