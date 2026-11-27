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
    @Dependency(EditionRepositoryKey.self) var editionRepository
    @Dependency(PeriodRepositoryKey.self) var periodRepository

    init() {
        @Dependency(\.dataStoreFactory) var storeFactory
        self.store = storeFactory()
    }

    func get(id: String) async throws -> Route? {
        let matchingRecords = try await records(id: id).filter { $0.id == id }
        guard matchingRecords.count < 2 else {
            throw Error.conflict("ルートIDが重複しています。")
        }
        return matchingRecords.first?.content
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
        guard let district = try await districtRepository.get(id: districtId),
              let edition = try await editionRepository.get(festivalId: district.festivalId, year: year) else {
            return []
        }
        return try await query(by: districtId, editionId: edition.id)
    }

    func post(_ item: Route) async throws -> Route {
        let editionId = try await editionId(for: item)
        try await store.put(RouteRecord(item, editionId: editionId))
        return item
    }

    func put(_ item: Route) async throws -> Route {
        let editionId = try await editionId(for: item)
        let record = RouteRecord(item, editionId: editionId)
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

    private func editionId(for route: Route) async throws -> Edition.ID {
        guard let period = try await periodRepository.get(id: route.periodId) else {
            throw Error.notFound("指定されたルートに合致する日程が取得できませんでした。")
        }
        guard let editionId = period.editionId else {
            throw Error.badRequest("ルートの日程にEditionが設定されていません。")
        }
        guard let edition = try await editionRepository.get(id: editionId) else {
            throw Error.notFound("指定されたルートに合致するEditionが取得できませんでした。")
        }
        guard let district = try await districtRepository.get(id: route.districtId) else {
            throw Error.notFound("指定されたルートに合致する地区が取得できませんでした。")
        }
        guard edition.festivalId == district.festivalId else {
            throw Error.badRequest("ルートの日程と地区の祭典が一致しません。")
        }
        return editionId
    }
}

struct RouteRecord: RecordProtocol {
    typealias Content = Route

    let pk: String
    let sk: String
    let type: String
    let id: String
    let content: Route

    init(_ content: Route, editionId: Edition.ID) {
        let keys = Self.makeKeys(content.id, districtId: content.districtId, editionId: editionId)
        self.pk = keys.pk
        self.sk = keys.sk
        self.type = Self.type
        self.id = content.id
        self.content = content
    }

    static func makeKeys(
        _ id: Route.ID,
        districtId: District.ID,
        editionId: Edition.ID
    ) -> (pk: String, sk: String) {
        (
            pk: "\(pkPrefix)\(districtId)",
            sk: "\(skPrefix)\(editionId)#\(id)"
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

    static func makeKeys(id: Route.ID) -> (indexName: String, pk: QueryCondition, sk: QueryCondition) {
        (
            indexName: idIndexName,
            pk: .equals("type", type),
            sk: .equals("id", id)
        )
    }

    static let pkPrefix = "DISTRICT#"
    static let skPrefix = "ROUTE#"
    static let type = String(describing: Route.self).uppercased()
    static let idIndexName = "index-type-id"
}
