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
        let periods = try await fetchPeriodsForLocationVisibility(festivalId: festivalId, now: now)

        if LocationPublicAccess.isPublic(now: now, periods: periods) {
            return try await locationRepository.query(by: festivalId)
        }

        if case let .district(districtId) = user {
            let location = try await locationRepository.get(festivalId: festivalId, districtId: districtId)
            return location.map { [$0] } ?? []
        }

        return []
    }
    
    func get(districtId: String, user: UserRole, now: Date) async throws -> FloatLocation? {
        guard let district = try await districtRepository.get(id: districtId) else {
            throw Error.notFound("指定された地区が見つかりません")
        }

        let periods = try await fetchPeriodsForLocationVisibility(festivalId: district.festivalId, now: now)
        let isPublic = LocationPublicAccess.isPublic(now: now, periods: periods)
        let canViewOutside = LocationPublicAccess.canViewOutsidePublicHours(user: user, districtId: district.id)

        guard isPublic || canViewOutside else { return nil }

        guard let location = try await locationRepository.get(festivalId: district.festivalId, districtId: district.id) else {
            throw Error.notFound("位置情報が見つかりません")
        }
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
    private func fetchPeriodsForLocationVisibility(festivalId: Festival.ID, now: Date) async throws -> [Period] {
        let nowYear = SimpleDate.from(now).year
        async let currentYear = periodRepository.query(by: festivalId, year: nowYear)
        async let nextYear = periodRepository.query(by: festivalId, year: nowYear + 1)
        let (current, next) = try await (currentYear, nextYear)
        return current + next
    }

}
