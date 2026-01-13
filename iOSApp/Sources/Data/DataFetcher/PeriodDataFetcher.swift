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

protocol PeriodDataFetcherProtocol: Sendable {
    associatedtype QueryType = PeriodDataFetcher.Query
    func fetchAll(festivalID: Festival.ID, query: QueryType) async throws
    func fetch(periodID: Period.ID) async throws
    func update(_ period: Period) async throws
}


struct PeriodDataFetcher: PeriodDataFetcherProtocol {
    enum Query: Sendable, Equatable {
        case all
        case year(Int)
        case latest

        var queryItems: [String: Any] {
            switch self {
            case .all:
                return [:]
            case .year(let y):
                return ["year": y]
            case .latest:
                return ["year": "latest"]
            }
        }
    }

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
        @Dependency(AuthServiceKey.self) var authService
        guard let token = await authService.getAccessToken() else { throw APIError.unauthorized(message: "") }
        let period: Period = try await client.put(path: "/periods/\(period.id)", body: period, accessToken: token)
        try await sync(period)
    }

    func fetch(periodID: Period.ID) async throws {
        let period: Period = try await client.get(path: "/periods/\(periodID)")
        try await sync(period)
    }

    private func syncAll(_ periods: [Period], festivalId: Festival.ID, query: Query) async throws {
        try await database.write { db in
            var oldPeriods: [Period] = try fetchOldPeriods(festivalId: festivalId, query: query, maxYear: periods.map(keyPath: \.date.year).max(), db: db)
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
