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

protocol DistrictDataFetcherProtocol: Sendable {
    func create(name: String, email: String, festivalId: String) async throws
    func update(district: District, performances: [Performance]) async throws
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
        guard let token = await getAccessToken() else { throw APIError.unauthorized(message: "") }
        let result: DistrictPack = try await client.post(path: "/festivals/\(festivalId)", body: draft, accessToken: token)
        try await syncPack(result)
    }

    func update(district: District, performances: [Performance] ) async throws {
        let draft: DistrictPack = .init(district: district, performances: performances)
        guard let token = await getAccessToken() else { throw APIError.unauthorized(message: "") }
        let result: DistrictPack = try await client.put(path: "/districts/\(district.id)", body: draft, accessToken: token)
        try await syncPack(result)
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

    private func syncPack(_ pack: DistrictPack) async throws {
        let id: District.ID = pack.district.id
        try await database.write { db in
            let oldPerformances = try performanceStore.fetchAll(where: { $0.districtId == id }, from: db)
            let (insertedPerformances, deletedPerformanceIds) = oldPerformances.diff(with: pack.performances)
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
}

extension DistrictDataFetcher {
    func getAccessToken() async -> String? {
        @Dependency(AuthServiceKey.self) var authService
        let token = await authService.getAccessToken()
        return token
    }
}
extension DependencyValues {
    var districtDataFetcher: DistrictDataFetcherProtocol {
        get { self[DistrictDataFetcherKey.self] }
        set { self[DistrictDataFetcherKey.self] = newValue }
    }
}

