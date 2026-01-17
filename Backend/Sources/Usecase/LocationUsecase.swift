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
    func query(by festivalId: String, user: UserRole, now: Date) async throws -> [FloatLocation]
    func get(districtId: String, user: UserRole, now: Date) async throws -> FloatLocation?
    func put(_ location: FloatLocation, user: UserRole) async throws -> FloatLocation
    func delete(districtId: District.ID, user: UserRole) async throws
}

// MARK: - LocationUsecase
struct LocationUsecase: LocationUsecaseProtocol {
    @Dependency(LocationRepositoryKey.self) var locationRepository
    @Dependency(DistrictRepositoryKey.self) var districtRepository
    @Dependency(FestivalRepositoryKey.self) var festivalRepository
    @Dependency(PeriodRepositoryKey.self) var periodRepository
    
    func query(by festivalId: String, user: UserRole, now: Date) async throws -> [FloatLocation] {
        let locations: [FloatLocation]
        
        if case let .headquarter(userId) = user, userId == festivalId {
            locations = try await queryForAdmin(festivalId)
        } else {
            locations = try await queryForPublic(festivalId: festivalId, now: now)
        }
        return locations
    }
    
    func get(districtId: String, user: UserRole, now: Date) async throws -> FloatLocation? {
        guard let district = try await districtRepository.get(id: districtId) else {
            throw Error.notFound("指定された地区が見つかりません")
        }

        let location: FloatLocation?
        
        if case let .headquarter(headId) = user, headId == district.festivalId {
            location = try await getForAdmin(festivalId: headId, districtId: district.id)
        } else if case let .district(dId) = user, dId == districtId {
            location = try await getForAdmin(festivalId: district.festivalId, districtId: district.id)
        } else {
            location = try await getForPublic(festivalId: district.festivalId, districtId: district.id, now: now)
        }
        guard let location else { throw Error.notFound("位置情報が見つかりません") }
        return location
    }
    
    func put(_ location: FloatLocation, user: UserRole) async throws -> FloatLocation {
        guard user.id == location.districtId else {
            throw Error.unauthorized("アクセス権限がありません")
        }
        guard let district = try await districtRepository.get(id: location.districtId) else {
            throw Error.notFound("地区が見つかりません")
        }
        return try await locationRepository.put(location, festivalId: district.festivalId)
    }
    
    func delete(districtId: District.ID, user: UserRole) async throws {
        guard user.id == districtId else {
            throw Error.unauthorized("アクセス権限がありません")
        }
        guard let district = try await districtRepository.get(id: districtId) else {
            throw Error.notFound("地区が見つかりません")
        }
        try await locationRepository.delete(festivalId: district.festivalId, districtId: district.id)
    }
    
}

extension LocationUsecase {
    private func queryForPublic(festivalId: Festival.ID, now: Date) async throws -> [FloatLocation] {
        let periods = try await periodRepository.query(by: festivalId, year: SimpleDate.now.year)
        // TODO: Period修正
        guard periods.first(where: { $0.contains(now) }) != nil else { throw Error.unauthorized("時間外のため配信を停止しています。") }

        return try await locationRepository.query(by: festivalId)
    }

    private func queryForAdmin(_ id: Festival.ID) async throws -> [FloatLocation] {
        return try await locationRepository.query(by: id)
    }

    private func getForAdmin(festivalId: String, districtId: District.ID) async throws -> FloatLocation? {
        return try await locationRepository.get(festivalId: festivalId, districtId: districtId)
    }

    private func getForPublic(festivalId: String, districtId: District.ID, now: Date) async throws -> FloatLocation? {
        let periods = try await periodRepository.query(by: festivalId, year: SimpleDate.now.year)
        // TODO: Period修正
        guard periods.first(where: { $0.contains(now) }) != nil else { throw Error.unauthorized("時間外のため配信を停止しています。") }
        
        return try await locationRepository.get(festivalId: festivalId, districtId: districtId)
    }

}
