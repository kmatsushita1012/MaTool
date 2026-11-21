//
//  RouteRepository.swift
//  MaTool
//
//  Created by 松下和也 on 2025/11/14.
//

import Dependencies
import Foundation
import Shared

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
    func query(by districtId: String, editionId: Edition.ID) async throws -> [Route]
    func query(by districtId: String, year: Int) async throws -> [Route]
    func post(_ route: Route) async throws -> Route
    func put(_ route: Route) async throws -> Route
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
        self.store = storeFactory(DynamoDBConfiguration.tableName)
    }

    func get(id: String) async throws -> Route? {
        try await records(id: id).first?.content
    }

    func query(by districtId: String) async throws -> [Route] {
        let keys = RouteRecord.makeKeys(districtId: districtId)
        let records = try await store.query(queryConditions: [keys.pk, keys.sk], as: RouteRecord.self)
        return records.map(\.content).sorted { $0.id < $1.id }
    }

    func query(by districtId: String, editionId: Edition.ID) async throws -> [Route] {
        let keys = RouteRecord.makeKeys(districtId: districtId, editionId: editionId)
        let records = try await store.query(queryConditions: [keys.pk, keys.sk], as: RouteRecord.self)
        return records.map(\.content).sorted { $0.id < $1.id }
    }

    func query(by districtId: String, year: Int) async throws -> [Route] {
        let keys = RouteRecord.makeKeys(districtId: districtId, year: year)
        let records = try await store.query(
            indexName: keys.indexName,
            queryConditions: [keys.pk, keys.sk],
            as: RouteRecord.self
        )
        return records.map(\.content)
    }

    func post(_ item: Route) async throws -> Route {
        let (editionId, date) = try await periodAndDate(for: item)
        try await store.put(RouteRecord(item, editionId: editionId, date: date))
        return item
    }

    func put(_ item: Route) async throws -> Route {
        let (editionId, date) = try await periodAndDate(for: item)
        let record = RouteRecord(item, editionId: editionId, date: date)
        let existingRecords = try await records(id: item.id)

        for existingRecord in existingRecords
        where existingRecord.id == item.id
            && (existingRecord.pk != record.pk || existingRecord.sk != record.sk) {
            try await store.delete(pk: existingRecord.pk, sk: existingRecord.sk)
        }

        try await store.put(record)
        return item
    }

    func delete(id: String) async throws {
        for record in try await records(id: id) where record.id == id {
            try await store.delete(pk: record.pk, sk: record.sk)
        }
    }

    func delete(_ route: Route) async throws {
        let existingRecords = try await records(id: route.id)
        for record in existingRecords
        where record.id == route.id && record.content.districtId == route.districtId {
            try await store.delete(pk: record.pk, sk: record.sk)
        }
    }

    private func records(id: Route.ID) async throws -> [RouteRecord] {
        let keys = RouteRecord.makeKeys(id: id)
        return try await store.query(
            indexName: keys.indexName,
            queryConditions: [keys.pk, keys.sk],
            as: RouteRecord.self
        )
    }

    private func periodAndDate(for route: Route) async throws -> (Edition.ID, SimpleDate) {
        guard let period = try await periodRepository.get(id: route.periodId) else {
            throw Error.notFound("指定されたルートに合致する日程が取得できませんでした。")
        }
        guard let editionId = period.editionId else {
            throw Error.badRequest("ルートの日程にEditionが設定されていません。")
        }
        let districts = try await districtRepository.query(by: period.festivalId)
        guard districts.contains(where: {
            $0.id == route.districtId && $0.festivalId == period.festivalId
        }) else {
            throw Error.notFound("指定されたルートに合致する地区が取得できませんでした。")
        }
        return (editionId, period.date)
    }
}

struct RouteRecord: RecordProtocol {
    typealias Content = Route

    let pk: String
    let sk: String
    let type: String
    let date: String
    let id: String
    let content: Route

    init(_ content: Route, editionId: Edition.ID, date: SimpleDate) {
        let keys = Self.makeKeys(content.id, districtId: content.districtId, editionId: editionId, date: date)
        self.pk = keys.pk
        self.sk = keys.sk
        self.type = Self.type
        self.date = keys.dateKey
        self.id = content.id
        self.content = content
    }

    static func makeKeys(
        _ id: Route.ID,
        districtId: District.ID,
        editionId: Edition.ID,
        date: SimpleDate
    ) -> (pk: String, sk: String, dateKey: String) {
        (
            pk: "\(pkPrefix)\(districtId)",
            sk: "\(skPrefix)\(editionId)#\(id)",
            dateKey: "\(skPrefix)\(datePrefix)\(date.sortableKey)"
        )
    }

    static func makeKeys(districtId: District.ID) -> (pk: QueryCondition, sk: QueryCondition) {
        (
            pk: .equals("pk", "\(pkPrefix)\(districtId)"),
            sk: .beginsWith("sk", skPrefix)
        )
    }

    static func makeKeys(districtId: District.ID, editionId: Edition.ID) -> (pk: QueryCondition, sk: QueryCondition) {
        (
            pk: .equals("pk", "\(pkPrefix)\(districtId)"),
            sk: .beginsWith("sk", "\(skPrefix)\(editionId)#")
        )
    }

    static func makeKeys(districtId: District.ID, year: Int) -> (indexName: String, pk: QueryCondition, sk: QueryCondition) {
        (
            indexName: dateIndexName,
            pk: .equals("pk", "\(pkPrefix)\(districtId)"),
            sk: .beginsWith("date", "\(skPrefix)\(datePrefix)\(year)")
        )
    }

    static func makeKeys(id: Route.ID) -> (indexName: String, pk: QueryCondition, sk: QueryCondition) {
        (
            indexName: idIndexName,
            pk: .equals("type", type),
            sk: .equals("id", id)
        )
    }

    static let pkPrefix = "DISTRICT#"
    static let skPrefix = "ROUTE#"
    static let datePrefix = "DATE#"
    static let type = String(describing: Route.self).uppercased()
    static let idIndexName = "index-type-id"
    static let dateIndexName = "index-DATE"
}
