//
//  SQLiteStore.swift
//  MaTool
//
//  Created by 松下和也 on 2026/01/12.
//

import SQLiteData
import Dependencies
import Shared


// DependencyKeys for each @Table entity in Shared
enum FestivalStoreKey: DependencyKey {
    static let liveValue: any SQLiteStoreProtocol<Festival> = SQLiteStore<Festival>()
}

enum CheckpointStoreKey: DependencyKey {
    static let liveValue: any SQLiteStoreProtocol<Checkpoint> = SQLiteStore<Checkpoint>()
}

enum HazardSectionStoreKey: DependencyKey {
    static let liveValue: any SQLiteStoreProtocol<HazardSection> = SQLiteStore<HazardSection>()
}

enum DistrictStoreKey: DependencyKey {
    static let liveValue: any SQLiteStoreProtocol<District> = SQLiteStore<District>()
}

enum PerformanceStoreKey: DependencyKey {
    static let liveValue: any SQLiteStoreProtocol<Performance> = SQLiteStore<Performance>()
}

enum PeriodStoreKey: DependencyKey {
    static let liveValue: any SQLiteStoreProtocol<Period> = SQLiteStore<Period>()
}

enum RouteStoreKey: DependencyKey {
    static let liveValue: any SQLiteStoreProtocol<Route> = SQLiteStore<Route>()
}

enum PointStoreKey: DependencyKey {
    static let liveValue: any SQLiteStoreProtocol<Point> = SQLiteStore<Point>()
}

enum FloatLocationStoreKey: DependencyKey {
    static let liveValue: any SQLiteStoreProtocol<FloatLocation> = SQLiteStore<FloatLocation>()
}

protocol SQLiteStoreProtocol<Content>: Sendable {
    associatedtype Content: PrimaryKeyedTable & Sendable & Identifiable
    
    func fetchAll(@QueryFragmentBuilder<Bool> where predicate: (Content.TableColumns) -> [QueryFragment], from db: Database) throws -> [Content]
    func insert(_ item: Content, at db: Database) throws
    func insert(_ items: [Content], at db: Database) throws
    func deleteAll(@QueryFragmentBuilder<Bool> where predicate: (Content.TableColumns) -> [QueryFragment], from db: Database) throws
    func deleteAll(_ primaryKeys: some Sequence<some QueryExpression<Content.PrimaryKey>> , from db: Database) throws
}

struct SQLiteStore<Content: PrimaryKeyedTable & Sendable & Identifiable>: SQLiteStoreProtocol {
    
    func fetchAll(@QueryFragmentBuilder<Bool> where predicate: (Content.TableColumns) -> [QueryFragment], from db: Database) throws -> [Content] {
        try Content.where(predicate).fetchAll(db).map{  Content.init(queryOutput: $0) }
    }
    
    
    func insert(_ item: Content, at db: Database) throws {
        _ = try Content.insert { item }.execute(db)
    }
    
    func insert(_ items: [Content], at db: Database) throws {
        _ = try Content.insert { items }.execute(db)
    }
    
    func deleteAll(@QueryFragmentBuilder<Bool> where predicate: (Content.TableColumns) -> [QueryFragment], from db: Database) throws {
        _ = try Content.where(predicate).delete().execute(db)
    }
    
    func deleteAll(
        _ primaryKeys: some Sequence<some QueryExpression<Content.PrimaryKey>>, from db: Database
    ) throws {
        _ = try Content.find(primaryKeys).delete().execute(db)
    }
}

extension SQLiteStoreProtocol {
    
    func delete(_ id: Content.PrimaryKey, from db: Database) throws {
        try deleteAll([id], from: db)
    }
    
    func fetchAll(@QueryFragmentBuilder<Bool> where predicate: (Content.TableColumns) -> [QueryFragment]) async throws -> [Content] {
        @Dependency(\.defaultDatabase) var database
        return try await database.read{ db in
            try fetchAll(where: predicate, from: db)
        }
    }
}


