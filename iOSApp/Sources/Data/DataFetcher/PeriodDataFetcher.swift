//
//  PeriodDataFetcher.swift
//  MaTool
//
//  Created by 松下和也 on 2026/01/13.
//

import Shared
import Dependencies
import SQLiteData


enum PeriodDataFetcherKey: DependencyKey {
    static let liveValue: any PeriodDataFetcherProtocol = PeriodDataFetcher()
}

protocol PeriodDataFetcherProtocol: DataFetcher {
    func fetchAll(festivalID: Festival.ID, query: Query) async throws
    func fetch(_ id: Period.ID) async throws
    func update(_ period: Period) async throws
    func create(_ period: Period) async throws
    func delete(_ id: Period.ID) async throws
}


struct PeriodDataFetcher: PeriodDataFetcherProtocol {

    @Dependency(HTTPClientKey.self) var client
    @Dependency(PeriodStoreKey.self) var periodStore
    @Dependency(RouteStoreKey.self) var routeStore
    @Dependency(\.defaultDatabase) var database

    func fetchAll(festivalID: Festival.ID, query: Query) async throws {
        let path = "/festivals/\(festivalID)/periods"
        let periods: [Period] = try await client.get(path: path, query: query.queryItems)
        try await syncAll(periods, festivalId: festivalID, query: query)
    }

    func update(_ period: Period) async throws {
        let token = try await getToken()
        let period: Period = try await client.put(path: "/periods/\(period.id)", body: period, accessToken: token)
        try await sync(period)
    }
    
    func create(_ period: Period) async throws {
        let token = try await getToken()
        let period: Period = try await client.post(path: "/festivals/\(period.festivalId)/periods", body: period, accessToken: token)
        try await sync(period)
    }

    func fetch(_ id: Period.ID) async throws {
        let period: Period = try await client.get(path: "/periods/\(id)")
        try await sync(period)
    }
    
    func delete(_ id: Period.ID) async throws {
        let token = try await getToken()
        let result: Empty = try await client.delete(path: "/periods/\(id)", accessToken: token)
        try await database.write{ db in
            try periodStore.delete(id, from: db)
        }
    }

    private func syncAll(_ periods: [Period], festivalId: Festival.ID, query: Query) async throws {
        try await database.write { db in
            let oldPeriods: [Period] = try fetchOldPeriods(festivalId: festivalId, query: query, maxYear: periods.map(keyPath: \.date.year).max(), db: db)
            let (insertedPeriods, deletedPeriodIds) = oldPeriods.diff(with: periods)
            try periodStore.deleteAll(deletedPeriodIds, from: db)
            try routeStore.deleteAll(where: { $0.periodId.in(deletedPeriodIds) }, from: db)
            try periodStore.insert(insertedPeriods, at: db)
        }
    }
    
    private func fetchOldPeriods(festivalId: Festival.ID, query: Query, maxYear: Int? = nil, db: Database) throws -> [Period] {
        switch query {
        case .all:
            try periodStore.fetchAll(where: { $0.festivalId == festivalId }, from: db)
        case .year(let year):
            try periodStore.fetchAll(where: { $0.festivalId == festivalId && $0.date.inYear(year) }, from: db)
        case .latest:
            if let maxYear {
                try periodStore.fetchAll(where: { $0.festivalId == festivalId && $0.date.inYear(maxYear) }, from: db)
            } else {
                try periodStore.fetchAll(where: { $0.festivalId == festivalId }, from: db)
            }
        }
    }
    
    private func sync(_ period: Period) async throws {
        try await database.write { db in
            try periodStore.insert(period, at: db)
        }
    }
}
