//
//  FestivalDataFetcher.swift
//  MaTool
//
//  Created by 松下和也 on 2026/01/12.
//

import Shared
import Dependencies
import SQLiteData

enum FestivalDataFetcherKey: DependencyKey {
    static let liveValue: any FestivalDataFetcherProtocol = FestivalDataFetcher()
}

protocol FestivalDataFetcherProtocol: Sendable {
    func update(festival: Festival, checkPoints: [Checkpoint], hazardSections: [HazardSection]) async throws
    func fetchAll() async throws
    func fetch(festivalID: Festival.ID) async throws
}

extension DependencyValues {
    var festivalDataFetcher: FestivalDataFetcherProtocol {
        get { self[FestivalDataFetcherKey.self] }
        set { self[FestivalDataFetcherKey.self] = newValue }
    }
}

struct FestivalDataFetcher: FestivalDataFetcherProtocol {
    @Dependency(HTTPClientKey.self) var client
    @Dependency(FestivalStoreKey.self) var festivalStore
    @Dependency(CheckpointStoreKey.self) var checkpointStore
    @Dependency(HazardSectionStoreKey.self) var hazardSectionStore
    @Dependency(\.defaultDatabase) var database
    
    func update(festival: Festival, checkPoints: [Checkpoint], hazardSections: [HazardSection] ) async throws {
        guard let token = await getAccessToken() else { throw APIError.unauthorized(message: "") }
        let draft: FestivalPack = .init(festival: festival, checkpoints: checkPoints, hazardSections: hazardSections)
        let result: FestivalPack = try await client.put(path: "/festivals/\(festival.id)", body: draft, accessToken: token)
        try await syncPack(result)
    }
    
    func fetchAll() async throws {
        let festivals: [Festival] = try await client.get(path: "/festivals")
        try await syncAll(festivals)
    }
    
    func fetch(festivalID: Festival.ID) async throws {
        let pack: FestivalPack = try await client.get(path: "/festivals/\(festivalID)")
        try await syncPack(pack)
    }
    
    private func syncPack(_ pack: FestivalPack) async throws {
        let id: Festival.ID = pack.festival.id
        try await database.write{ db in
            let oldCheckpoints = try checkpointStore.fetchAll(where: { $0.festivalId == id }, from: db)
            let oldHazardSections = try hazardSectionStore.fetchAll(where: { $0.festivalId == id }, from: db)
            let (insertedCheckpoints, deletedCheckpointIds) = oldCheckpoints.diff(with: pack.checkpoints)
            let (insertedHazardSections, deletedHazardSectionIds) = oldHazardSections.diff(with: pack.hazardSections)
            try festivalStore.delete(id, from: db)
            try checkpointStore.deleteAll(deletedCheckpointIds, from: db)
            try hazardSectionStore.deleteAll(deletedHazardSectionIds, from: db)
            try festivalStore.insert(pack.festival, at: db)
            try checkpointStore.insert(insertedCheckpoints , at: db)
            try hazardSectionStore.insert(insertedHazardSections, at: db)
        }
    }
    
    private func syncAll(_ festivals: [Festival]) async throws {
        try await database.write{ db in
            try festivalStore.deleteAll(from: db)
            try festivalStore.insert(festivals, at: db)
        }
    }
}

extension FestivalDataFetcher {
    func getAccessToken() async -> String? {
        @Dependency(AuthServiceKey.self) var authService
        let token = await authService.getAccessToken()
        return token
    }
}
