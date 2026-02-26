//
//  PassageRepository.swift
//  matool-backend
//
//  Created by 松下和也 on 2026/02/17.
//

import Dependencies
import Shared
import Foundation

fileprivate typealias PRecord = Record<RoutePassage>

// MARK: - Dependencies
enum PassageRepositoryKey: DependencyKey {
    static let liveValue: any PassageRepositoryProtocol = PassageRepository()
}

extension DependencyValues {
    var passageRepository: any PassageRepositoryProtocol {
        get { self[PassageRepositoryKey.self] }
        set { self[PassageRepositoryKey.self] = newValue }
    }
}

// MARK: - PassageRepositoryProtocol
protocol PassageRepositoryProtocol: Repository where Content == RoutePassage {
    func query(by routeId: String) async throws -> [RoutePassage]
    func put(_ item: RoutePassage) async throws -> RoutePassage
    func post(_ item: RoutePassage) async throws -> RoutePassage
    func delete(_ item: RoutePassage) async throws
    func delete(by routeId: Route.ID) async throws
}

// MARK: - PassageRepository
struct PassageRepository: PassageRepositoryProtocol {
    
    private let store: DataStore

    init() {
        @Dependency(\.dataStoreFactory) var storeFactory
        self.store = storeFactory("matool")
    }
    
    func get(id: RoutePassage.ID) async throws -> RoutePassage? {
        let keys = PRecord.makeKeys(id)
        let records = try await store.query(
            indexName: keys.indexName,
            queryConditions: [keys.pk, keys.sk], as: PRecord.self)
        return records.first?.content
    }

    func query(by routeId: String) async throws -> [RoutePassage] {
        let keys = PRecord.makeKeys(routeId: routeId)
        let records = try await store.query(queryConditions: [ keys.pk, keys.sk ], ascending: true, as: PRecord.self)
        return records.map(\.content)
    }

    func put(_ item: Shared.RoutePassage) async throws -> Shared.RoutePassage {
        let record = PRecord(item)
        _ = try await store.put(record)
        return item
    }
    
    func post(_ item: Shared.RoutePassage) async throws -> Shared.RoutePassage {
        let record = PRecord(item)
        _ = try await store.put(record)
        return item
    }
    
    func delete(_ item: Shared.RoutePassage) async throws {
        let keys = PRecord.makeKeys(routeId: item.routeId, id: item.id)
        _ = try await store.delete(pk: keys.pk, sk: keys.sk)
    }
    
    func delete(by routeId: Route.ID) async throws {
        let passages = try await query(by: routeId)

        try await withThrowingTaskGroup(of: Error?.self) { group in
            for passage in passages {
                group.addTask {
                    do {
                        try await delete(passage)
                        return nil
                    } catch {
                        throw error
                    }
                }
            }

            var errors = [Error]()
            for try await error in group {
                if let error = error {
                    errors.append(error)
                }
            }

            if !errors.isEmpty {
                throw Error.internalServerError("地点の削除処理に失敗しました。")
            }
        }
    }
}

extension PRecord {
    init(_ content: RoutePassage) {
        let keys = Self.makeKeys(routeId: content.routeId, id: content.id)
        self.init(pk: keys.pk, sk: keys.sk, type: Self.type, content: content)
    }
    // update
    static func makeKeys(routeId: String, id: String) -> (pk: String, sk: String) {
        (pk: "\(pkPrefix)\(routeId)", sk: "\(skPrefix)\(id)")
    }
    // query
    static func makeKeys(routeId: String) -> (pk: QueryCondition, sk: QueryCondition) {
        (pk: .equals("pk", "\(pkPrefix)\(routeId)"), sk: .beginsWith("sk", skPrefix))
    }
    
    static func makeKeys(_ id: String) -> (indexName: String, pk: QueryCondition, sk: QueryCondition) {
        (indexName: Self.typeIndex, pk: .equals("type", type), sk: .equals("sk", "\(skPrefix)\(id)"))
    }

    static let pkPrefix: String = "ROUTE#"
    static let skPrefix: String = "PASSAGE#"
    static let type = String(describing: RoutePassage.self).uppercased()
    static let typeIndex = "index-TYPE"
}
