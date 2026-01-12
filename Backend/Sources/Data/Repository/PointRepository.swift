//
//  PointRepository.swift
//  MaTool
//
//  Created by 松下和也 on 2025/11/14.
//

import Dependencies
import Shared
import Foundation

fileprivate typealias PRecord = Record<Point>

// MARK: - Dependencies
enum PointRepositoryKey: DependencyKey {
    static let liveValue: any PointRepositoryProtocol = PointRepository()
}

extension DependencyValues {
    var pointRepository: any PointRepositoryProtocol {
        get { self[PointRepositoryKey.self] }
        set { self[PointRepositoryKey.self] = newValue }
    }
}

// MARK: - PointRepositoryProtocol
protocol PointRepositoryProtocol: Repository where Content == Point {
    func query(by routeId: String) async throws -> [Point]
    func put(_ item: Point) async throws -> Point
    func post(_ item: Point) async throws -> Point
    func delete(_ item: Point) async throws
    func delete(by routeId: Route.ID) async throws
}

// MARK: - PointRepository
struct PointRepository: PointRepositoryProtocol {
    
    private let store: DataStore

    init() {
        @Dependency(\.dataStoreFactory) var storeFactory
        self.store = storeFactory("matool")
    }
    
    func get(id: Point.ID) async throws -> Point? {
        let keys = PRecord.makeKeys(id)
        let records = try await store.query(
            indexName: keys.indexName,
            queryConditions: [keys.pk, keys.sk], as: PRecord.self)
        return records.first?.content
    }

    func query(by routeId: String) async throws -> [Point] {
        let keys = PRecord.makeKeys(routeId: routeId)
        let records = try await store.query(queryConditions: [ keys.pk, keys.sk ], ascending: true, as: PRecord.self)
        return records.map(\.content)
    }

    func put(_ item: Shared.Point) async throws -> Shared.Point {
        let record = PRecord(item)
        _ = try await store.put(record)
        return item
    }
    
    func post(_ item: Shared.Point) async throws -> Shared.Point {
        let record = PRecord(item)
        _ = try await store.put(record)
        return item
    }
    
    func delete(_ item: Shared.Point) async throws {
        let keys = PRecord.makeKeys(item.id, routeId: item.routeId)
        _ = try await store.delete(pk: keys.pk, sk: keys.sk)
    }
    
    func delete(by routeId: Route.ID) async throws {
        let points = try await query(by: routeId)

        try await withThrowingTaskGroup(of: Error?.self) { group in
            for point in points {
                group.addTask {
                    do {
                        try await delete(point)
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
    init(_ content: Point) {
        let keys = Self.makeKeys(content.id, routeId: content.routeId)
        self.init(pk: keys.pk, sk: keys.sk, type: Self.type, content: content)
    }
    // update
    static func makeKeys(_ pointId: String, routeId: String, ) -> (pk: String, sk: String) {
        (pk: "\(pkPrefix)\(routeId)", sk: "\(skPrefix)\(pointId)")
    }
    // query
    static func makeKeys(routeId: String) -> (pk: QueryCondition, sk: QueryCondition) {
        (pk: .equals("pk", "\(pkPrefix)\(routeId)"), sk: .beginsWith("sk", skPrefix))
    }
    
    static func makeKeys(_ id: String) -> (indexName: String, pk: QueryCondition, sk: QueryCondition) {
        (indexName: Self.typeIndex, pk: .equals("type", type), sk: .beginsWith("sk", skPrefix))
    }

    static let pkPrefix: String = "ROUTE#"
    static let skPrefix: String = "POINT#"
    static let type = String(describing: Point.self).uppercased()
    static let typeIndex = "index-TYPE"
}
