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

func setupDatabase() throws -> DatabaseQueue {
    let databasePath = URL.documentsDirectory
        .appending(path: "matool.sqlite")
        .path()
    
    let database: DatabaseQueue = try DatabaseQueue(path: databasePath)
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
                "districtId" TEXT NOT NULL,
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
    
    try migrator.migrate(database)
    
    return database
}

