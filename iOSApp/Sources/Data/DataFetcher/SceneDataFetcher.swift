//
//  SceneDataFetcher.swift
//  MaTool
//
//  Created by 松下和也 on 2026/01/16.
//

import Dependencies
import Shared

enum SceneDataFetcherKey: DependencyKey {
    static let liveValue: SceneDataFetcherProtocol = SceneDataFetcher()
}

protocol SceneDataFetcherProtocol: DataFetcher {
    func launchFestival(festivalId: Festival.ID) async throws
    func launchFestival(districtId: District.ID) async throws -> Festival.ID
    func launchDistrict(districtId: District.ID) async throws -> Route.ID?
}

struct SceneDataFetcher: SceneDataFetcherProtocol {
    @Dependency(HTTPClientKey.self) var client
    @Dependency(\.defaultDatabase) var database
    
    @Dependency(FestivalStoreKey.self) var festivalStore
    @Dependency(CheckpointStoreKey.self) var checkpointStore
    @Dependency(HazardSectionStoreKey.self) var hazardSectionStore
    @Dependency(PeriodStoreKey.self) var periodStore
    @Dependency(DistrictStoreKey.self) var districtStore
    @Dependency(PerformanceStoreKey.self) var performanceStore
    @Dependency(RouteStoreKey.self) var routeStore
    @Dependency(PointStoreKey.self) var pointStore
    @Dependency(PassageStoreKey.self) var passageStore
    @Dependency(FloatLocationStoreKey.self) var locationStore
    
    func launchFestival(festivalId: Shared.Festival.ID) async throws {
        _ = try await launchFestival(path: "/festivals/\(festivalId)/launch")
    }
    
    func launchFestival(districtId: Shared.District.ID) async throws -> Festival.ID {
        let pack = try await launchFestival(path: "/districts/\(districtId)/launch-festival")
        return pack.festival.id
    }
        
    private func launchFestival(path: String) async throws -> LaunchFestivalPack {
        let token = try await getToken()
        async let deleteTask: () = database.write{ db in
            try festivalStore.deleteAll(from: db)
            try checkpointStore.deleteAll(from: db)
            try hazardSectionStore.deleteAll(from: db)
            try periodStore.deleteAll(from: db)
            try districtStore.deleteAll(from: db)
            try locationStore.deleteAll(from: db)
        }
        let pack: LaunchFestivalPack = try await client.get(path: path, accessToken: token)
        try await deleteTask
        try await database.write{ db in
            try festivalStore.upsert(pack.festival, at: db)
            try checkpointStore.upsert(pack.checkpoints, at: db)
            try hazardSectionStore.upsert(pack.hazardSections, at: db)
            try periodStore.upsert(pack.periods, at: db)
            try districtStore.upsert(pack.districts, at: db)
            try locationStore.upsert(pack.locations, at: db)
        }
        return pack
    }
    
    func launchDistrict(districtId: Shared.District.ID) async throws -> Route.ID? {
        let token = try await getToken()
        async let deleteTask: () = database.write{ db in
            try performanceStore.deleteAll(from: db)
            try routeStore.deleteAll(from: db)
            try pointStore.deleteAll(from: db)
            try passageStore.deleteAll(from: db)
        }
        let pack: LaunchDistrictPack = try await client.get(path: "/districts/\(districtId)/launch", accessToken: token)
        try await deleteTask
        try await database.write{ db in
            try performanceStore.upsert(pack.performances, at: db)
            try routeStore.upsert(pack.routes, at: db)
            try pointStore.upsert(pack.points, at: db)
            try passageStore.upsert(pack.passages, at: db)
        }
        return pack.currentRouteId
    }    
    
}
