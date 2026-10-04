//
//  RouteRepository.swift
//  MaTool
//
//  Created by 松下和也 on 2025/11/14.
//

import Dependencies
import Shared
import Foundation

// MARK: - Dependencies
enum RouteRepositoryKey: DependencyKey {
    static let liveValue: any RouteRepositoryProtocol = RouteRepository()
}

extension DependencyValues {
    var routeRepository: RouteRepositoryProtocol {
        get { self[RouteRepositoryKey.self] }
        set { self[RouteRepositoryKey.self] = newValue }
    }
}

// MARK: - RouteRepositoryProtocol
protocol RouteRepositoryProtocol: Sendable {
    func get(id: String) async throws -> Route?
    func query(by districtId: String) async throws -> [Route]
    func query(by districtId: String, year: Int) async throws -> [Route]
    func post(_ route: Route) async throws -> Route
    func put(_ route: Route) async throws -> Route
    func put(_ route: Route, replacing oldRoute: Route) async throws -> Route
    func delete(id: String) async throws
    func delete(_ route: Route) async throws
}

// MARK: - RouteRepository
struct RouteRepository: RouteRepositoryProtocol {
    private let store: DataStore
    
    @Dependency(DistrictRepositoryKey.self) var districtRepository
    @Dependency(PeriodRepositoryKey.self) var periodRepository

    init() {
        @Dependency(\.dataStoreFactory) var storeFactory
        self.store = storeFactory("matool")
    }

    func get(id: String) async throws -> Route? {
        let keys = RouteRecord.makeKeys(id)
        let records = try await store.query(indexName: keys.indexName,queryConditions: [keys.pk, keys.sk], as: RouteRecord.self)
        return records.first?.content
    }

    func query(by districtId: String) async throws -> [Route] {
        let keys = RouteRecord.makeKeys(districtId: districtId)
        let records = try await store.query(queryConditions: [ keys.pk, keys.sk ], as: RouteRecord.self)
        return records.map{ $0.content }
    }
    
    func query(by districtId: String, year: Int) async throws -> [Route] {
        let keys = RouteRecord.makeKeys(districtId: districtId, year: year)
        let records = try await store.query(indexName: keys.indexName, queryConditions: [ keys.pk, keys.sk ], as: RouteRecord.self)
        return records.map(\.content)
    }

    func post(_ item: Route) async throws -> Route {
        let date = try await getDate(item)
        let record = RouteRecord(item, date: date)
        try await ensureUnique(item, excludingRouteID: nil)
        try await store.transactRoute(record, replacing: nil)
        return item
    }

    func put(_ item: Route) async throws -> Route {
        let date = try await getDate(item)
        let oldRoute: Route?
        if let indexedRoute = try await get(id: item.id) {
            oldRoute = indexedRoute
        } else {
            oldRoute = try await get(id: item.id, inDistrict: item.districtId)
        }
        return try await persist(item, date: date, replacing: oldRoute)
    }

    func put(_ item: Route, replacing oldRoute: Route) async throws -> Route {
        let date = try await getDate(item)
        return try await persist(item, date: date, replacing: oldRoute)
    }

    private func persist(_ item: Route, date: SimpleDate, replacing oldRoute: Route?) async throws -> Route {
        let record = RouteRecord(item, date: date)
        try await ensureUnique(item, excludingRouteID: oldRoute?.id)
        try await store.transactRoute(record, replacing: oldRoute)
        return item
    }

    func delete(id: String) async throws {
        guard let target = try await get(id: id) else { return }
        try await delete(target)
    }

    func delete(_ route: Route) async throws {
        try await store.transactDeleteRoute(route)
    }

    private func ensureUnique(_ route: Route, excludingRouteID: Route.ID?) async throws {
        let keys = RouteRecord.makeKeys(districtId: route.districtId)
        let records = try await store.queryConsistent(
            queryConditions: [keys.pk, keys.sk],
            as: RouteRecord.self
        )
        let duplicate = records.contains { record in
            record.content.periodId == route.periodId
                && record.content.id != excludingRouteID
        }
        guard !duplicate else {
            throw Error.conflict("この地区・日程には既にルートが登録されています。")
        }
    }

    private func get(id: Route.ID, inDistrict districtId: District.ID) async throws -> Route? {
        let keys = RouteRecord.makeKeys(districtId: districtId)
        let records = try await store.queryConsistent(
            queryConditions: [keys.pk, keys.sk],
            as: RouteRecord.self
        )
        return records.first(where: { $0.content.id == id })?.content
    }
    
    private func getDate(_ content: Route) async throws -> SimpleDate {
        guard let period = try await periodRepository.get(id: content.periodId) else {
            throw Error.notFound("指定されたルートに合致する日程が取得できませんでした。")
        }
        let districts = try await districtRepository.query(by: period.festivalId)
        guard districts.contains(where: {
            $0.id == content.districtId && $0.festivalId == period.festivalId
        }) else {
            throw Error.notFound("指定されたルートに合致する地区が取得できませんでした。")
        }
        return period.date
    }
}

struct RouteRecord: RecordProtocol {
    typealias Content = Route
    
    let pk: String
    let sk: String
    let type: String
    let date: String
    let content: Shared.Route
}

extension RouteRecord {
    init(_ content: Route, date: SimpleDate) {
        let keys = Self.makeKeys(content.id, districtId: content.districtId, date: date)
        self.init(pk: keys.pk, sk: keys.sk, type: Self.type, date: keys.dateKey, content: content)
    }
    
    static func makeKeys(_ id: String, districtId: String, date: SimpleDate) -> (pk: String, sk: String, dateKey: String){
        (pk: "\(pkPrefix)\(districtId)", sk: "\(skPrefix)\(id)", dateKey: "\(skPrefix)\(datePrefix)\(date.sortableKey)")
    }
    
    static func makeKeys(_ id: String, districtId: String) -> (pk: String, sk: String){
        (pk: "\(pkPrefix)\(districtId)", sk: "\(skPrefix)\(id)")
    }
    
    static func makeKeys(districtId: String) -> (pk: QueryCondition, sk: QueryCondition){
        (pk: .equals("pk", "\(pkPrefix)\(districtId)"), sk: .beginsWith("sk", "\(skPrefix)"))
    }
    
    static func makeKeys(districtId: String, year: Int) -> (indexName: String, pk: QueryCondition, sk: QueryCondition){
        (indexName: dateIndexName, pk: .equals("pk", "\(pkPrefix)\(districtId)"), sk: .beginsWith("date", "\(skPrefix)\(datePrefix)\(year)"))
    }
    
    static func makeKeys(_ id: String) -> (indexName: String, pk: QueryCondition, sk: QueryCondition){
        (indexName: typeIndexName, pk: .equals("type", type), sk: .equals("sk", "\(skPrefix)\(id)"))
    }
    
    static let pkPrefix: String = "DISTRICT#"
    static let skPrefix: String = "ROUTE#"
    static let datePrefix: String = "DATE#"
    static let type = String(describing: Route.self).uppercased()
    static let typeIndexName = "index-TYPE"
    static let dateIndexName = "index-DATE"
}

struct RouteUniqueRecord: RecordProtocol {
    typealias Content = String

    let pk: String
    let sk: String
    let type: String
    let routeId: String
    let content: String

    init(_ route: Route) {
        let keys = Self.makeKeys(districtId: route.districtId, periodId: route.periodId)
        self.init(pk: keys.pk, sk: keys.sk, type: Self.type, routeId: route.id, content: route.id)
    }

    static func makeKeys(districtId: String, periodId: String) -> (pk: String, sk: String) {
        (pk: "\(RouteRecord.pkPrefix)\(districtId)", sk: "\(prefix)\(periodId)")
    }

    static let prefix = "ROUTE_UNIQUE#"
    static let type = "ROUTE_UNIQUE"
}
