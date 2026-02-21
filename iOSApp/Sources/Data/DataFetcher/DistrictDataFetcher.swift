//
//  DistrictDataFetcher.swift
//  MaTool
//
//  Created by 松下和也 on 2026/01/13.
//

import Shared
import Dependencies
import SQLiteData

enum DistrictDataFetcherKey: DependencyKey {
    static let liveValue: any DistrictDataFetcherProtocol = DistrictDataFetcher()
}

protocol DistrictDataFetcherProtocol: DataFetcher {
    func create(name: String, email: String, festivalId: String) async throws
    func update(district: District, performances: [Performance]) async throws
    func update(district: District) async throws
    func fetchAll(festivalID: Festival.ID) async throws
    func fetch(districtID: District.ID) async throws
}

struct DistrictDataFetcher: DistrictDataFetcherProtocol {
    @Dependency(HTTPClientKey.self) var client
    @Dependency(DistrictStoreKey.self) var districtStore
    @Dependency(PerformanceStoreKey.self) var performanceStore
    @Dependency(\.defaultDatabase) var database
    
    func create(name: String, email: String, festivalId: String) async throws {
        let draft: DistrictCreateForm = .init(name: name, email: email)
        let token = try await getToken()
        let result: DistrictPack = try await client.post(path: "/festivals/\(festivalId)/districts", body: draft, accessToken: token)
        try await syncPack(result)
    }
    
    func update(district: District, performances: [Performance] ) async throws {
        let draft: DistrictPack = .init(district: district, performances: performances)
        let token = try await getToken()
        let result: DistrictPack = try await client.put(path: "/districts/\(district.id)", body: draft, accessToken: token)
        try await syncPack(result)
    }
    
    func update(district: District) async throws {
        let token = try await getToken()
        let result: District = try await client.put(path: "/districts/\(district.id)/core", body: district, accessToken: token)
        try await sync(result)
    }
    
    // fetch all districts for a festival
    func fetchAll(festivalID: Festival.ID) async throws {
        let districts: [District] = try await client.get(path: "/festivals/\(festivalID)/districts")
        try await syncAll(districts)
    }
    
    func fetch(districtID: District.ID) async throws {
        let pack: DistrictPack = try await client.get(path: "/districts/\(districtID)")
        try await syncPack(pack)
    }
}
    
extension DistrictDataFetcher {
    private func syncPack(_ pack: DistrictPack) async throws {
        let id: District.ID = pack.district.id
        try await database.write { db in
            let oldPerformances = try performanceStore.fetchAll(where: { $0.districtId.eq(id) }, from: db)
            let (insertedPerformances, deletedPerformanceIds) = oldPerformances.diff(with: pack.performances)
            try districtStore.delete(pack.district.id, from: db)
            try performanceStore.deleteAll(deletedPerformanceIds, from: db)
            try districtStore.insert(pack.district, at: db)
            try performanceStore.insert(insertedPerformances, at: db)
        }
    }
    
    private func syncAll(_ districts: [District]) async throws {
        try await database.write { db in
            try districtStore.insert(districts, at: db)
        }
    }
    
    private func sync(_ district: District) async throws {
        try await database.write { db in
            try districtStore.delete(district.id, from: db)
            try districtStore.insert(district, at: db)
        }
    }
}
