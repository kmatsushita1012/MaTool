import Dependencies
import Foundation
import Shared
import Testing
@testable import Backend

struct PeriodRepositoryTest {
    @Test
    func get_正常_種別IDインデックス検索で先頭を返す() async throws {
        let period = Period.mock(id: "period-1", festivalId: "festival-1")
        var lastCalledIndexName: String?
        var lastCalledKeyConditions: [QueryCondition] = []

        let dataStore = DataStoreMock(
            queryHandler: { indexName, keyConditions, _, _, _, _ in
                lastCalledIndexName = indexName
                lastCalledKeyConditions = keyConditions
                return try JSONEncoder().encode([PeriodRecord(period)])
            }
        )
        let subject = make(dataStore: dataStore)

        let result = try await subject.get(id: period.id)

        #expect(result == period)
        #expect(dataStore.queryCallCount == 1)
        #expect(lastCalledIndexName == "index-type-id")
        #expect(lastCalledKeyConditions.count == 2)
        #expect(lastCalledKeyConditions.contains(where: isTypeEqualsPeriod))
        #expect(lastCalledKeyConditions.contains(where: { isEquals($0, field: "id", value: period.id) }))
    }

    @Test
    func query_正常_年指定でprefix検索する() async throws {
        let period = Period.mock(id: "period-1", festivalId: "festival-1", date: .init(year: 2026, month: 2, day: 22))
        var lastCalledIndexName: String?
        var lastCalledKeyConditions: [QueryCondition] = []

        let dataStore = DataStoreMock(
            queryHandler: { indexName, keyConditions, _, _, _, _ in
                lastCalledIndexName = indexName
                lastCalledKeyConditions = keyConditions
                return try JSONEncoder().encode([PeriodRecord(period)])
            }
        )
        let subject = make(dataStore: dataStore)

        let result = try await subject.query(by: period.festivalId, year: 2026)

        #expect(result == [period])
        #expect(dataStore.queryCallCount == 1)
        #expect(lastCalledIndexName == nil)
        #expect(lastCalledKeyConditions.contains(where: { isEquals($0, field: "pk", value: "FESTIVAL#\(period.festivalId)") }))
        #expect(lastCalledKeyConditions.contains(where: { isBeginsWith($0, field: "sk", prefix: "PERIOD#2026") }))
    }

    @Test
    func query_正常_祭典指定で全期間prefix検索する() async throws {
        let period = Period.mock(id: "period-1", festivalId: "festival-1")
        var lastCalledKeyConditions: [QueryCondition] = []

        let dataStore = DataStoreMock(
            queryHandler: { _, keyConditions, _, _, _, _ in
                lastCalledKeyConditions = keyConditions
                return try JSONEncoder().encode([PeriodRecord(period)])
            }
        )
        let subject = make(dataStore: dataStore)

        let result = try await subject.query(by: period.festivalId)

        #expect(result == [period])
        #expect(dataStore.queryCallCount == 1)
        #expect(lastCalledKeyConditions.contains(where: { isEquals($0, field: "pk", value: "FESTIVAL#\(period.festivalId)") }))
        #expect(lastCalledKeyConditions.contains(where: { isBeginsWith($0, field: "sk", prefix: "PERIOD#") }))
    }

    @Test
    func post_正常_レコード化してputする() async throws {
        let period = Period.mock(id: "period-1", festivalId: "festival-1", date: .init(year: 2026, month: 2, day: 22), start: .init(hour: 9, minute: 0))
        var lastCalledRecord: PeriodRecord?

        let dataStore = DataStoreMock(
            putHandler: { item in
                lastCalledRecord = try decodeFromEncodable(item, as: PeriodRecord.self)
            }
        )
        let subject = make(dataStore: dataStore)

        let result = try await subject.post(period)

        #expect(result == period)
        #expect(dataStore.putCallCount == 1)
        #expect(lastCalledRecord?.content == period)
        #expect(lastCalledRecord?.pk == "FESTIVAL#\(period.festivalId)")
    }

    @Test
    func put_正常_レコード化してputする() async throws {
        let period = Period.mock(id: "period-2", festivalId: "festival-1", date: .init(year: 2026, month: 3, day: 1), start: .init(hour: 12, minute: 0))
        var lastCalledRecord: PeriodRecord?

        let dataStore = DataStoreMock(
            putHandler: { item in
                lastCalledRecord = try decodeFromEncodable(item, as: PeriodRecord.self)
            }
        )
        let subject = make(dataStore: dataStore)

        let result = try await subject.put(period)

        #expect(result == period)
        #expect(dataStore.putCallCount == 1)
        #expect(lastCalledRecord?.content == period)
        #expect(lastCalledRecord?.pk == "FESTIVAL#\(period.festivalId)")
    }

    @Test
    func delete_正常_主キーでdeleteする() async throws {
        let festivalId = "festival-1"
        let date = SimpleDate(year: 2026, month: 2, day: 22)
        let start = SimpleTime(hour: 10, minute: 30)
        var lastCalledKeyPair: (pk: String?, sk: String?) = (nil, nil)

        let dataStore = DataStoreMock(
            deleteHandler: { keys in
                lastCalledKeyPair = (keys["pk"] as? String, keys["sk"] as? String)
            }
        )
        let subject = make(dataStore: dataStore)

        try await subject.delete(festivalId: festivalId, date: date, start: start)

        #expect(dataStore.deleteCallCount == 1)
        #expect(lastCalledKeyPair.pk == "FESTIVAL#\(festivalId)")
        #expect(lastCalledKeyPair.sk == "PERIOD#\(date.sortableKey)#\(start.sortableKey)")
    }

    @Test
    func get_異常_依存エラーを透過() async {
        let dataStore = DataStoreMock(
            queryHandler: { _, _, _, _, _, _ in throw TestError.intentional }
        )
        let subject = make(dataStore: dataStore)

        await #expect(throws: TestError.intentional) {
            _ = try await subject.get(id: "period-1")
        }
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

    @Test
    func post_異常_依存エラーを透過() async {
        let period = Period.mock(id: "period-1", festivalId: "festival-1")
        let dataStore = DataStoreMock(
            putHandler: { _ in throw TestError.intentional }
        )
        let subject = make(dataStore: dataStore)

        await #expect(throws: TestError.intentional) {
            _ = try await subject.post(period)
        }
    }

    @Test
    func put_異常_依存エラーを透過() async {
        let period = Period.mock(id: "period-1", festivalId: "festival-1")
        let dataStore = DataStoreMock(
            putHandler: { _ in throw TestError.intentional }
        )
        let subject = make(dataStore: dataStore)

        await #expect(throws: TestError.intentional) {
            _ = try await subject.put(period)
        }
    }

    @Test
    func delete_異常_依存エラーを透過() async {
        let dataStore = DataStoreMock(
            deleteHandler: { _ in throw TestError.intentional }
        )
        let subject = make(dataStore: dataStore)

        await #expect(throws: TestError.intentional) {
            try await subject.delete(
                festivalId: "festival-1",
                date: .init(year: 2026, month: 2, day: 22),
                start: .init(hour: 10, minute: 30)
            )
        }
    }
}

private extension PeriodRepositoryTest {
    func make(dataStore: DataStoreMock = .init()) -> PeriodRepository {
        withDependencies {
            $0[DataStoreFactoryKey.self] = { _ in dataStore }
        } operation: {
            PeriodRepository()
        }
    }

    func isTypeEqualsPeriod(_ condition: QueryCondition) -> Bool {
        isEquals(condition, field: "type", value: "PERIOD")
    }

    func isEquals(_ condition: QueryCondition, field: String, value: String) -> Bool {
        guard case let .equals(actualField, actualValue) = condition else { return false }
        guard let actual = actualValue as? String else { return false }
        return actualField == field && actual == value
    }

    func isBeginsWith(_ condition: QueryCondition, field: String, prefix: String) -> Bool {
        guard case let .beginsWith(actualField, actualPrefix) = condition else { return false }
        return actualField == field && actualPrefix == prefix
    }
}
