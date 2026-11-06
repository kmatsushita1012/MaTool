import Dependencies
import Foundation
import Shared
@testable import Backend

func send(
    _ method: Application.Method,
    path: String,
    route: Route,
    store: RouteMemoryDataStore,
    periods: [Period]
) async throws -> Application.Response {
    let district = District.mock(id: "district-1", festivalId: "festival-1")
    let periodByID = Dictionary(uniqueKeysWithValues: periods.map { ($0.id, $0) })
    return try await withDependencies {
        $0[DataStoreFactoryKey.self] = { _ in store }
        $0[DistrictRepositoryKey.self] = DistrictRepositoryMock(
            getHandler: { _ in district },
            queryHandler: { _ in [district] }
        )
        $0[PeriodRepositoryKey.self] = PeriodRepositoryMock(getHandler: { periodByID[$0] })
        $0[FestivalRepositoryKey.self] = FestivalRepositoryMock()
        $0[PointRepositoryKey.self] = PointRepositoryMock(
            queryHandler: { _ in [] },
            postHandler: { $0 },
            putHandler: { $0 }
        )
        $0[PassageRepositoryKey.self] = PassageRepositoryMock(queryHandler: { _ in [] })
    } operation: {
        let routeRepository = RouteRepository()
        return try await withDependencies {
            $0[RouteRepositoryKey.self] = routeRepository
            $0[RouteUsecaseKey.self] = RouteUsecase()
            $0[RouteControllerKey.self] = RouteController()
            $0[DistrictControllerKey.self] = DistrictControllerMock()
            $0[LocationControllerKey.self] = LocationControllerMock()
            $0[SceneControllerKey.self] = SceneControllerMock()
            $0[PeriodControllerKey.self] = PeriodControllerMock()
        } operation: {
            let app = Application { DistrictRouter(); OtherRouter() }
            let points = [
                Point.mock(
                    id: "\(route.id)-start",
                    routeId: route.id,
                    time: .init(hour: 9, minute: 0),
                    anchor: .start
                ),
                Point.mock(
                    id: "\(route.id)-end",
                    routeId: route.id,
                    index: 1,
                    time: .init(hour: 10, minute: 0),
                    anchor: .end
                )
            ]
            let pack = RoutePack(route: route, points: points, passages: [])
            var request = Application.Request.make(method: method, path: path, body: try pack.toString())
            request.user = .district("district-1")
            return await app.handle(request)
        }
    }
}

actor RouteMemoryDataStore: DataStore {
    private var routeRecords: [String: RouteRecord] = [:]
    private var uniqueRoutes: [String: String] = [:]

    func put<T: RecordProtocol>(_ item: T) async throws {}

    func transactRoute(_ record: RouteRecord, replacing oldRoute: Route?) async throws {
        let route = record.content
        let newKeys = RouteRecord.makeKeys(route.id, districtId: route.districtId)
        let newRecordKey = Self.key(newKeys.pk, newKeys.sk)
        let newUnique = RouteUniqueRecord(route)
        let newUniqueKey = Self.key(newUnique.pk, newUnique.sk)

        if let markerOwner = uniqueRoutes[newUniqueKey], markerOwner != route.id {
            throw Application.Error.conflict("duplicate marker")
        }
        if routeRecords.values.contains(where: {
            $0.content.id != route.id
                && $0.content.districtId == route.districtId
                && $0.content.periodId == route.periodId
        }) {
            throw Application.Error.conflict("duplicate route")
        }

        if let oldRoute {
            let oldKeys = RouteRecord.makeKeys(oldRoute.id, districtId: oldRoute.districtId)
            let oldRecordKey = Self.key(oldKeys.pk, oldKeys.sk)
            guard let stored = routeRecords[oldRecordKey], stored.content.periodId == oldRoute.periodId else {
                throw Application.Error.conflict("stale route")
            }
            if oldRecordKey != newRecordKey {
                routeRecords.removeValue(forKey: oldRecordKey)
            }
            let oldUnique = RouteUniqueRecord(oldRoute)
            let oldUniqueKey = Self.key(oldUnique.pk, oldUnique.sk)
            if oldUniqueKey != newUniqueKey, let owner = uniqueRoutes[oldUniqueKey], owner == route.id {
                uniqueRoutes.removeValue(forKey: oldUniqueKey)
            }
        } else if routeRecords[newRecordKey] != nil {
            throw Application.Error.conflict("route already exists")
        }

        routeRecords[newRecordKey] = record
        uniqueRoutes[newUniqueKey] = route.id
    }

    func transactDeleteRoute(_ route: Route) async throws {
        let keys = RouteRecord.makeKeys(route.id, districtId: route.districtId)
        let recordKey = Self.key(keys.pk, keys.sk)
        guard routeRecords[recordKey]?.content.periodId == route.periodId else {
            throw Application.Error.conflict("stale route")
        }
        let unique = RouteUniqueRecord(route)
        let uniqueKey = Self.key(unique.pk, unique.sk)
        if uniqueRoutes[uniqueKey] == nil || uniqueRoutes[uniqueKey] == route.id {
            uniqueRoutes.removeValue(forKey: uniqueKey)
        }
        routeRecords.removeValue(forKey: recordKey)
    }

    nonisolated func get<T: RecordProtocol>(keys: [String: Codable], as type: T.Type) async throws -> T? { nil }
    nonisolated func delete(keys: [String: Codable]) async throws {}
    func scan<T: RecordProtocol>(_ type: T.Type, ignoreDecodeError: Bool) async throws -> [T] { [] }

    func query<T: RecordProtocol>(
        indexName: String?,
        keyConditions: [QueryCondition],
        filterConditions: [FilterCondition],
        limit: Int?,
        ascending: Bool,
        as type: T.Type
    ) async throws -> [T] {
        let matches = routeRecords.values.filter { record in
            keyConditions.allSatisfy { condition in Self.matches(condition, record: record) }
        }
        let limited = limit.map { Array(matches.prefix($0)) } ?? Array(matches)
        return try limited.map { record in
            try JSONDecoder().decode(T.self, from: JSONEncoder().encode(record))
        }
    }

    func route(id: String) -> Route? {
        routeRecords.values.first(where: { $0.content.id == id })?.content
    }

    func routes() -> [Route] {
        routeRecords.values.map(\.content)
    }

    func markerOwner(districtId: String, periodId: String) -> String? {
        let keys = RouteUniqueRecord.makeKeys(districtId: districtId, periodId: periodId)
        return uniqueRoutes[Self.key(keys.pk, keys.sk)]
    }

    func seedLegacy(_ route: Route) {
        let date = SimpleDate(year: 2026, month: 2, day: 22)
        let keys = RouteRecord.makeKeys(route.id, districtId: route.districtId, date: date)
        routeRecords[Self.key(keys.pk, keys.sk)] = RouteRecord(route, date: date)
    }

    func seedMarker(for route: Route) {
        let record = RouteUniqueRecord(route)
        uniqueRoutes[Self.key(record.pk, record.sk)] = route.id
    }

    private static func matches(_ condition: QueryCondition, record: RouteRecord) -> Bool {
        switch condition {
        case let .equals(field, rawValue):
            guard let value = rawValue as? String else { return false }
            switch field {
            case "pk": return record.pk == value
            case "sk": return record.sk == value
            case "type": return record.type == value
            default: return false
            }
        case let .beginsWith(field, prefix):
            switch field {
            case "pk": return record.pk.hasPrefix(prefix)
            case "sk": return record.sk.hasPrefix(prefix)
            default: return false
            }
        case .between:
            return false
        }
    }

    private static func key(_ pk: String, _ sk: String) -> String { "\(pk)|\(sk)" }
}
