//
//  LocationDataFetcher.swift
//  MaTool
//
//  Created by 松下和也 on 2026/01/15.
//

import Dependencies
import Shared

enum LocationDataFetcherKey: DependencyKey {
    static let liveValue: LocationDataFetcherProtocol = LocationDataFetcher()
}

protocol LocationDataFetcherProtocol: DataFetcher {
    func fetchAll(festivalId: Festival.ID) async throws
    func fetch(districtId: District.ID) async throws
    func update(_ location: FloatLocation) async throws
    func delete(districtId: District.ID) async throws
}

struct LocationDataFetcher: LocationDataFetcherProtocol{
    
    @Dependency(FloatLocationStoreKey.self) var store
    @Dependency(\.defaultDatabase) var database
    @Dependency(HTTPClientKey.self) var client
    
    func fetchAll(festivalId: Shared.Festival.ID) async throws {
        let token = try await getToken()
        let locations: [FloatLocation] = try await client.get(path: "/festivals/\(festivalId)/locations", accessToken: token)
        try await sync(locations)
    }
    
    func fetch(districtId: Shared.District.ID) async throws {
        let token = try await getToken()
        let location: FloatLocation = try await client.get(path: "/district/\(districtId)/locations", accessToken: token)
        try await sync(location)
    }
    
    func update(_ location: Shared.FloatLocation) async throws {
        let token = try await getToken()
        let location: FloatLocation = try await client.put(path: "/district/\(location.districtId)/locations", body: location,  accessToken: token)
        try await sync(location)
    }
    
    func delete(districtId: District.ID) async throws {
        let token = try await getToken()
        let _: Empty = try await client.delete(path: "/district/\(districtId)/locations", accessToken: token)
        try await database.write{ db in
            try store.deleteAll(where: { $0.districtId.eq(districtId) }, from: db)
        }
    }
}

extension LocationDataFetcher{
    private func sync(_ locations: [FloatLocation]) async throws {
        let ids = locations.map(\.id)
        try await database.write{ db in
            try store.deleteAll(where: { $0.districtId.in(ids) }, from: db)
            try store.insert(locations, at: db)
        }
    }
    
    private func sync(_ location: FloatLocation) async throws {
        let districtId = location.districtId
        try await database.write{ db in
            try store.deleteAll(where: { $0.districtId.eq(districtId) }, from: db)
            try store.insert(location, at: db)
        }
    }
}
