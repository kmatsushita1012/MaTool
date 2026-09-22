import iOSShared
//
//  SQLiteStore+Setup.swift
//  MaTool
//
//  Created by 松下和也 on 2026/01/17.
//

import SQLiteData
import Dependencies
import Foundation
import Shared

private func makeDatabaseMigrator() -> DatabaseMigrator {
    var migrator = DatabaseMigrator()
    
    migrator.registerMigration("CreateAllTables") { db in
        try #sql("""
            CREATE TABLE IF NOT EXISTS "festivals" (
                "id" TEXT PRIMARY KEY NOT NULL,
                "name" TEXT NOT NULL,
                "subname" TEXT NOT NULL,
                "description" TEXT,
                "prefecture" TEXT NOT NULL,
                "city" TEXT NOT NULL,
                "base" TEXT NOT NULL,
                "image" TEXT NOT NULL
            )
        """).execute(db)

        try #sql("""
            CREATE TABLE IF NOT EXISTS "checkpoints" (
                "id" TEXT PRIMARY KEY NOT NULL,
                "festivalId" TEXT NOT NULL,
                "name" TEXT NOT NULL,
                "description" TEXT
            )
        """).execute(db)

        try #sql("""
            CREATE TABLE IF NOT EXISTS "hazardsections" (
                "id" TEXT PRIMARY KEY NOT NULL,
                "title" TEXT NOT NULL,
                "festivalId" TEXT NOT NULL,
                "coordinates" TEXT NOT NULL
            )
        """).execute(db)

        try #sql("""
            CREATE TABLE IF NOT EXISTS "districts" (
                "id" TEXT PRIMARY KEY NOT NULL,
                "name" TEXT NOT NULL,
                "festivalId" TEXT NOT NULL,
                "order" INTEGER NOT NULL DEFAULT 0,
                "group" TEXT,
                "description" TEXT,
                "base" TEXT,
                "area" TEXT NOT NULL,
                "image" TEXT NOT NULL,
                "visibility" INTEGER NOT NULL DEFAULT 0,
                "isEditable" INTEGER NOT NULL DEFAULT 1
            )
        """).execute(db)

        try #sql("""
            CREATE TABLE IF NOT EXISTS "performances" (
                "id" TEXT PRIMARY KEY NOT NULL,
                "name" TEXT NOT NULL,
                "districtId" TEXT NOT NULL,
                "performer" TEXT NOT NULL,
                "description" TEXT
            )
        """).execute(db)

        try #sql("""
            CREATE TABLE IF NOT EXISTS "periods" (
                "id" TEXT PRIMARY KEY NOT NULL,
                "festivalId" TEXT NOT NULL,
                "date" TEXT NOT NULL,
                "title" TEXT NOT NULL,
                "start" TEXT NOT NULL,
                "end" TEXT NOT NULL
            )
        """).execute(db)

        try #sql("""
            CREATE TABLE IF NOT EXISTS "routes" (
                "id" TEXT PRIMARY KEY NOT NULL,
                "districtId" TEXT NOT NULL,
                "periodId" TEXT NOT NULL,
                "visibility" INTEGER NOT NULL DEFAULT 0,
                "description" TEXT
            )
        """).execute(db)

        try #sql("""
            CREATE TABLE IF NOT EXISTS "points" (
                "id" TEXT PRIMARY KEY NOT NULL,
                "routeId" TEXT NOT NULL,
                "coordinate" TEXT NOT NULL,
                "time" TEXT,
                "checkpointId" TEXT,
                "performanceId" TEXT,
                "anchor" TEXT,
                "index" INTEGER NOT NULL DEFAULT 0,
                "isBoundary" INTEGER NOT NULL DEFAULT 0
            )
        """).execute(db)
        
        try #sql("""
            CREATE TABLE IF NOT EXISTS "routePassages" (
                "id" TEXT PRIMARY KEY NOT NULL,
                "routeId" TEXT NOT NULL,
                "districtId" TEXT,
                "memo" TEXT,
                "order" INTEGER NOT NULL DEFAULT 0
            )
        """).execute(db)

        try #sql("""
            CREATE TABLE IF NOT EXISTS "floatlocations" (
                "id" TEXT PRIMARY KEY NOT NULL,
                "districtId" TEXT NOT NULL,
                "coordinate" TEXT NOT NULL,
                "timestamp" TEXT NOT NULL
            )
        """).execute(db)
    }
    return migrator
}

private func makeDefaultDatabase() throws -> DatabaseQueue {
    let databasePath = URL.documentsDirectory
        .appending(path: "matool.sqlite")
        .path()
    return try DatabaseQueue(path: databasePath)
}

public enum InfrastructureResolver {
    public static func configure() throws {
        let database = try makeDefaultDatabase()
        try makeDatabaseMigrator().migrate(database)

        prepareDependencies {
            $0.defaultDatabase = database
            $0[HTTPClientKey.self] = HTTPClient(base: $0.values.apiBaseUrl)
            $0[AppStatusClientKey.self] = AppStatusClient(urlString: $0.values.appStatusUrl)
            $0[AuthProviderKey.self] = AuthProvider.awsLiveValue
            $0[LocationProviderKey.self] = LocationProvider()
            $0[UserDefaultsClientKey.self] = UserDefaultsClient.infrastructureLiveValue
            $0[UserDefaltsManagerKey.self] = UserDefaltsManager()
            $0[AdManagerKey.self] = AdManager(
                configuration: .init(
                    appID: $0.values.admobAppId,
                    publicMapInterstitialUnitID: $0.values.publicMapInterstitialAdUnitId
                )
            )

            $0[FestivalStoreKey.self] = SQLiteStore<Festival>()
            $0[CheckpointStoreKey.self] = SQLiteStore<Checkpoint>()
            $0[HazardSectionStoreKey.self] = SQLiteStore<HazardSection>()
            $0[DistrictStoreKey.self] = SQLiteStore<District>()
            $0[PerformanceStoreKey.self] = SQLiteStore<Performance>()
            $0[PeriodStoreKey.self] = SQLiteStore<Period>()
            $0[RouteStoreKey.self] = SQLiteStore<Route>()
            $0[PointStoreKey.self] = SQLiteStore<Point>()
            $0[PassageStoreKey.self] = SQLiteStore<RoutePassage>()
            $0[FloatLocationStoreKey.self] = SQLiteStore<FloatLocation>()
        }
    }
}
