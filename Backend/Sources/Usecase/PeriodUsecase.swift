//
//  PeriodUsecase.swift
//  matool-backend
//
//  Created by 松下和也 on 2025/12/07.
//

import Dependencies
import Shared

// MARK: - Dependencies
enum PeriodUsecaseKey: DependencyKey {
    static let liveValue: PeriodUsecaseProtocol = PeriodUsecase()
}

protocol PeriodUsecaseProtocol: Sendable {
    func get(id: String) async throws -> Period
    func query(by festivalId: String, year: Int) async throws -> [Period]
    func query(by festivalId: String) async throws -> [Period]
    func post(festivalId: String, period: Period, user: UserRole) async throws -> Period
    func put(period: Period, user: UserRole) async throws -> Period
    func delete(id: String, user: UserRole) async throws
}

struct PeriodUsecase: PeriodUsecaseProtocol {
    @Dependency(PeriodRepositoryKey.self) var repository
    @Dependency(DistrictRepositoryKey.self) var districtRepository
    @Dependency(RouteRepositoryKey.self) var routeRepository
    @Dependency(PointRepositoryKey.self) var pointRepository
    @Dependency(PassageRepositoryKey.self) var passageRepository
    
    func get(id: String) async throws -> Period {
        guard let period = try await repository.get(id: id) else {
            throw Error.notFound("指定された日程が取得できませんでした。")
        }
        return period
    }
    
    func query(by festivalId: String, year: Int) async throws -> [Period] {
        return try await repository.query(by: festivalId, year: year)
    }
    
    func query(by festivalId: String) async throws -> [Period] {
        return try await repository.query(by: festivalId)
    }
    
    func post(festivalId: String, period: Period, user: UserRole) async throws -> Period {
        guard case let .headquarter(id) = user,
                festivalId == id && period.festivalId == id else {
            throw Error.unauthorized("アクセス権限がありません。")
        }
        return try await repository.post(period)
    }
    
    func put(period: Period, user: UserRole) async throws -> Period {
        guard case let .headquarter(id) = user,
                period.festivalId == id else {
            throw Error.unauthorized("アクセス権限がありません。")
        }
        return try await repository.put(period)
    }
    
    func delete(id: String, user: UserRole) async throws {
        let target = try await repository.get(id: id)
        guard let target,
            case let .headquarter(id) = user,
              target.festivalId == id else {
            throw Error.unauthorized("アクセス権限がありません。")
        }
        try await deleteRoutes(for: target)
        return try await repository.delete(festivalId: target.festivalId, date: target.date, start: target.start )
    }

    private func deleteRoutes(for period: Period) async throws {
        // Route has no periodId index, so search each district's route partition.
        let districts = try await districtRepository.query(by: period.festivalId)
        for district in districts {
            let routes = try await routeRepository.query(by: district.id)
            for route in routes where route.periodId == period.id {
                try await pointRepository.delete(by: route.id)
                try await passageRepository.delete(by: route.id)
                try await routeRepository.delete(route)
            }
        }
    }
}
