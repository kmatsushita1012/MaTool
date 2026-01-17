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
    func delete(id: String) async throws
}

// MARK: - RouteRepository
struct RouteRepository: RouteRepositoryProtocol {
    private let store: DataStore
    
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

    func delete(id: String) async throws {
        guard let target = try await get(id: id) else { return }
        let keys = RouteRecord.makeKeys(target.id, districtId: target.districtId)
        try await store.delete(pk: keys.pk, sk: keys.sk)
        return
    }
    
    private func getDate(_ content: Route) async throws -> SimpleDate {
        guard let period = try await periodRepository.get(id: content.periodId) else {
            throw Error.notFound("指定されたルートに合致する日程が取得できませんでした。")
        }
        return period.date
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
        (pk: "\(pkPrefix)\(districtId)", sk: "\(skPrefix)\(id)", dateKey: "\(datePrefix)\(date.sortableKey)")
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
