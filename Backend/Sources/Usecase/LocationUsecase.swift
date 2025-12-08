//
//  LocationUsecase.swift
//  matool-backend
//
//  Created by 松下和也 on 2025/11/30.
//

import Dependencies
import Shared
import Foundation

// MARK: - Dependencies
enum LocationUsecaseKey: DependencyKey {
    static let liveValue: any LocationUsecaseProtocol = LocationUsecase()
}

// MARK: - LocationUsecaseProtocol
protocol LocationUsecaseProtocol: Sendable {
    func query(by festivalId: String, user: UserRole, now: Date) async throws -> [FloatLocationGetDTO]
    func get(_ districtId: String, user: UserRole) async throws -> FloatLocationGetDTO
    func put(_ location: FloatLocation, user: UserRole) async throws -> FloatLocation
    func delete(_ id: String, user: UserRole) async throws
}

// MARK: - LocationUsecase
struct LocationUsecase: LocationUsecaseProtocol {
    @Dependency(LocationRepositoryKey.self) var locationRepository
    @Dependency(DistrictRepositoryKey.self) var districtRepository
    @Dependency(FestivalRepositoryKey.self) var festivalRepository
    
    func query(by festivalId: String, user: UserRole, now: Date) async throws -> [FloatLocationGetDTO] {
        let locations: [FloatLocation]
        
        if case let .headquarter(userId) = user, userId == festivalId {
            locations = try await scanForAdmin(festivalId)
        } else {
            locations = try await scanForPublic(festivalId, now: now)
        }
        
        let districts = try await districtRepository.query(by: festivalId)
        if districts.isEmpty {
            throw Error.notFound("指定された地区が見つかりません")
        }
        
        let districtMap: [String: District] = Dictionary(uniqueKeysWithValues: districts.map { ($0.id, $0) })
        // compactMapでqueryと同時に処理
        let publicLocations = locations.compactMap { location -> FloatLocationGetDTO? in
            guard let district = districtMap[location.districtId] else { return nil }
            return FloatLocationGetDTO(districtId: location.districtId, districtName: district.name, coordinate: location.coordinate, timestamp: location.timestamp)
        }
        
        return publicLocations
    }
    
    func get(_ districtId: String, user: UserRole) async throws -> FloatLocationGetDTO {
        
        
        guard let district = try await districtRepository.get(id: districtId) else {
            throw Error.notFound("指定された地区が見つかりません")
        }

        let location: FloatLocation?

        // admin when headquarter matches festival id OR the user is district owner
        if case let .headquarter(headId) = user, headId == district.festivalId {
            location = try await getForAdmin(districtId)
        } else if case let .district(dId) = user, dId == districtId {
            location = try await getForAdmin(districtId)
        } else {
            location = try await getForPublic(district)
        }

        guard let loc = location else {
            throw Error.notFound("位置情報が見つかりません")
        }

        return FloatLocationGetDTO(districtId: loc.districtId, districtName: district.name, coordinate: loc.coordinate, timestamp: loc.timestamp)
    }
    
    func put(_ location: FloatLocation, user: UserRole) async throws -> FloatLocation {
        guard user.id == location.districtId else {
            throw Error.unauthorized("アクセス権限がありません")
        }
        return try await locationRepository.put(location)
    }
    
    func delete(_ id: String, user: UserRole) async throws {
        guard user.id == id else {
            throw Error.unauthorized("アクセス権限がありません")
        }

        try await locationRepository.delete(districtId: id)
    }
    
}

extension LocationUsecase {
    private func scanForPublic(_ id: String, now: Date) async throws -> [FloatLocation] {
        guard let festival = try await festivalRepository.get(id: id) else {
            throw Error.notFound("指定された地域が見つかりません")
        }
        // TODO: Period修正
        var foundFlag = false
//        for period in festival.periods {
//            if period.start.toDate <= now && now <= period.end.toDate {
//                foundFlag = true
//                break
//            }
//        }
        
        guard foundFlag else { throw Error.forbidden("祭典期間外のため配信を停止しています。") }

        return try await locationRepository.scan()
    }

    private func scanForAdmin(_ id: String) async throws -> [FloatLocation] {
        return try await locationRepository.scan()
    }

    private func getForAdmin(_ districtId: String) async throws -> FloatLocation? {
        return try await locationRepository.get(id: districtId)
    }

    private func getForPublic(_ district: District) async throws -> FloatLocation? {
        guard let festival = try await festivalRepository.get(id: district.festivalId) else {
            throw Error.notFound("指定された地域が見つかりません")
        }

        let now = Date()
        // TODO: Period修正
//        guard festival.periods.first(where: { $0.contains(now) }) != nil else { throw Error.unauthorized("アクセス権限がありません") }
        throw Error.unauthorized("アクセス権限がありません")
        return try await locationRepository.get(id: district.id)
    }

}
