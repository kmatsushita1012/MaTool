import iOSShared
//
//  SQLiteStore.swift
//  MaTool
//
//  Created by 松下和也 on 2026/01/12.
//

import SQLiteData
import Dependencies
import Shared


public struct SQLiteStore<Content: PrimaryKeyedTable & Sendable & Identifiable>: SQLiteStoreProtocol {
    public init() {}

    public func fetchAll(@QueryFragmentBuilder<Bool> where predicate: (Content.TableColumns) -> [QueryFragment], from db: Database) throws -> [Content] {
        try Content.where(predicate).fetchAll(db).map{  Content.init(queryOutput: $0) }
    }
    
    public func fetchAll(from db: Database) throws -> [Content] {
        try Content.fetchAll(db).map{  Content.init(queryOutput: $0) }
    }
    
    
    public func insert(_ item: Content, at db: Database) throws {
        _ = try Content.insert { item }.execute(db)
    }
    
    public func insert(_ items: [Content], at db: Database) throws {
        _ = try Content.insert { items }.execute(db)
    }
    
    public func upsert(_ item: Content, at db: GRDB.Database) throws {
        _ = try Content.upsert{ item }.execute(db)
    }
    
    public func upsert(_ items: [Content], at db: GRDB.Database) throws {
        _ = try Content.upsert{ items }.execute(db)
    }
    
    
    public func deleteAll(@QueryFragmentBuilder<Bool> where predicate: (Content.TableColumns) -> [QueryFragment], from db: Database) throws {
        _ = try Content.where(predicate).delete().execute(db)
    }
    
    public func deleteAll(
        _ primaryKeys: some Sequence<some QueryExpression<Content.PrimaryKey>>, from db: Database
    ) throws {
        _ = try Content.find(primaryKeys).delete().execute(db)
    }
    
    public func deleteAll(from db: Database) throws {
        _ = try Content.delete().execute(db)
    }
}
