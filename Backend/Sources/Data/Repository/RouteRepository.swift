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
    func put(_ pack: RoutePack, oldPoints: [Point], oldPassages: [RoutePassage]) async throws -> RoutePack
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
        try await store.put(record)
        return item
    }

    func put(_ item: Route) async throws -> Route {
        let date = try await getDate(item)
        let record = RouteRecord(item, date: date)
        try await store.put(record)
        return item
    }

    func put(_ pack: RoutePack, oldPoints: [Point], oldPassages: [RoutePassage]) async throws -> RoutePack {
        let date = try await getDate(pack.route)
        var mutations = [try DataStoreMutation.put(RouteRecord(pack.route, date: date))]
        mutations.append(contentsOf: try childMutations(
            existing: oldPoints,
            replacing: pack.points,
            key: { DataStoreItemKey(pk: "ROUTE#\($0.routeId)", sk: "POINT#\($0.id)") },
            record: { Record(pk: "ROUTE#\($0.routeId)", sk: "POINT#\($0.id)", content: $0) }
        ))
        mutations.append(contentsOf: try childMutations(
            existing: oldPassages,
            replacing: pack.passages,
            key: { DataStoreItemKey(pk: "ROUTE#\($0.routeId)", sk: "PASSAGE#\($0.id)") },
            record: { Record(pk: "ROUTE#\($0.routeId)", sk: "PASSAGE#\($0.id)", content: $0) }
        ))

        try await store.transactWrite(mutations)
        return pack
    }

    func delete(id: String) async throws {
        guard let target = try await get(id: id) else { return }
        try await delete(target)
    }

    func delete(_ route: Route) async throws {
        let keys = RouteRecord.makeKeys(route.id, districtId: route.districtId)
        try await store.delete(pk: keys.pk, sk: keys.sk)
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

    private func childMutations<Element: Entity & Identifiable>(
        existing: [Element],
        replacing newItems: [Element],
        key: (Element) -> DataStoreItemKey,
        record: (Element) -> Record<Element>
    ) throws -> [DataStoreMutation] where Element.ID == String {
        let existingByID = Dictionary(uniqueKeysWithValues: existing.map { ($0.id, $0) })
        let newByID = Dictionary(uniqueKeysWithValues: newItems.map { ($0.id, $0) })
        var mutations: [DataStoreMutation] = []
        for item in existing {
            guard let replacement = newByID[item.id], key(item) == key(replacement) else {
                let itemKey = key(item)
                mutations.append(.delete(pk: itemKey.pk, sk: itemKey.sk))
                continue
            }
        }

        for item in newItems {
            guard let oldItem = existingByID[item.id], oldItem == item, key(oldItem) == key(item) else {
                mutations.append(try DataStoreMutation.put(record(item)))
                continue
            }
        }
        return mutations
    }
}

fileprivate struct RouteRecord: RecordProtocol {
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
