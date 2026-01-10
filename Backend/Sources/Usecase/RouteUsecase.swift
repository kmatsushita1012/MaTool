//
//  RouteUsecase.swift
//  matool-backend
//
//  Created by 松下和也 on 2025/11/30.
//

import Foundation
import Dependencies
import Shared

// MARK: - Dependencies
enum RouteUsecaseKey: DependencyKey {
    static let liveValue: RouteUsecaseProtocol = RouteUsecase()
}

// MARK: - RouteUsecaseProtocol
protocol RouteUsecaseProtocol: Sendable {
    func query(by districtId: String, user: UserRole) async throws -> RoutesResponse
    func query(by districtId: String, year: Int, user: UserRole) async throws -> RoutesResponse
    func get(id: String, user: UserRole) async throws -> RouteResponse
    func post(districtId: String, route: Route, user: UserRole) async throws -> Route
    func put(id: String, route: Route, user: UserRole) async throws -> Route
    func delete(id: String, user: UserRole) async throws
}

// MARK: - RouteUsecase
struct RouteUsecase: RouteUsecaseProtocol {    
    @Dependency(RouteRepositoryKey.self) var routeRepository
    @Dependency(DistrictRepositoryKey.self) var districtRepository
    @Dependency(PeriodRepositoryKey.self) var periodRepository
    @Dependency(LocationRepositoryKey.self) var locationRepository
    @Dependency(FestivalRepositoryKey.self) var festivalRepository
    
    func query(by districtId: String, user: UserRole) async throws -> RoutesResponse {
        guard let district = try await districtRepository.get(id: districtId) else {
            throw Error.notFound("指定された地区が見つかりません")
        }
        let periods = try await periodRepository.query(festivalId: district.festivalId)
        let routeRecords = try await routeRepository.query(by: districtId)
        
        let routeRecordByPeriodId = Dictionary(
            uniqueKeysWithValues: routeRecords.map { ($0.periodId, $0) }
        )
        
        let items: [RoutesResponse.Item] = makeItems(periods: periods, routeRecords: routeRecords, festivalId: district.festivalId, districtId: district.id, user: user)
        
        let response = RoutesResponse(
            districtId: district.id,
            districtName: district.name,
            items: items
        )
        return response
    }
    
    func query(by districtId: String, year: Int, user: UserRole) async throws -> RoutesResponse {
        guard let district = try await districtRepository.get(id: districtId) else {
            throw Error.notFound("指定された地区が見つかりません")
        }
        let periods = try await periodRepository.query(festivalId: district.festivalId, year: year)
        let routeRecords = try await routeRepository.query(by: districtId, year: year)
        
        let routeRecordByPeriodId = Dictionary(
            uniqueKeysWithValues: routeRecords.map { ($0.periodId, $0) }
        )
        
        let items: [RoutesResponse.Item] = periods.map {
            guard let record = routeRecordByPeriodId[$0.id] else {
                return .init(routeId: nil, isVisible: false, period: $0)
            }
            let hasAccess = hasAccess(festivalId: district.festivalId, districtId: districtId, visibility: record.item.visibility , user: user)
            return .init(routeId: record.id, isVisible: hasAccess, period: $0)
        }
        
        let response = RoutesResponse(
            districtId: district.id,
            districtName: district.name,
            items: items
        )
        return response
    }
    
    func get(id: String, user: UserRole) async throws -> RouteResponse {
        guard let routeRecord = try await routeRepository.get(id: id) else {
            throw Error.notFound("指定されたルートが見つかりません")
        }
        let route = routeRecord.item
        guard let district = try await districtRepository.get(id: route.districtId) else {
            throw Error.notFound("指定された地区が見つかりません")
        }
        guard hasAccess(festivalId: district.festivalId, districtId: route.districtId, visibility: route.visibility, user: user) else {
            throw Error.unauthorized("アクセス権限がありません")
        }

        guard let period = try await periodRepository.get(id: route.periodId) else {
            throw Error.unauthorized("データが見つかりません")
        }
        
        let response: RouteResponse = .init(
            districtId: district.id,
            districtName: district.name,
            period: period,
            route: route
        )
        return response
    }
    
    func post(districtId: String, route: Route, user: UserRole) async throws -> Route {
        guard districtId == user.id,
              route.districtId == user.id else {
            throw Error.unauthorized("アクセス権限がありません")
        }
        guard let period = try await periodRepository.get(id: route.periodId) else {
            throw Error.notFound("該当する日程が見つかりませんでした。")
        }
        let record = RouteRecord(item: route, year: period.date.year)
        let result = try await routeRepository.post(record)
        return result.item
    }
    
    func put(id: String, route: Route, user: UserRole) async throws -> Route {
        guard let old = try await routeRepository.get(id: id) else {
            throw Error.notFound("指定されたルートが見つかりません")
        }
        guard route.districtId == user.id,
              old.districtId == user.id else {
            throw Error.unauthorized("アクセス権限がありません")
        }
        guard let period = try await periodRepository.get(id: route.periodId) else {
            throw Error.notFound("該当する日程が見つかりませんでした。")
        }
        let record = RouteRecord(item: route, year: period.date.year)
        let result = try await routeRepository.put(record)
        return result.item
    }
    
    func delete(id: String, user: UserRole) async throws {
        guard let old = try await routeRepository.get(id: id) else {
            throw Error.notFound("指定されたルートが見つかりません")
        }
        if old.districtId != user.id {
            throw Error.unauthorized("アクセス権限がありません")
        }
        try await routeRepository.delete(id: id)
        return
    }
}

private extension RouteUsecase {
    func makeItems(periods: [Period], routeRecords: [RouteRecord], festivalId: String, districtId: String, user: UserRole) -> [RoutesResponse.Item]{
        let routeRecordByPeriodId = Dictionary(
            uniqueKeysWithValues: routeRecords.map { ($0.periodId, $0) }
        )
        
        let items: [RoutesResponse.Item] = periods.map{
            guard let record = routeRecordByPeriodId[$0.id] else {
                return .init(routeId: nil, isVisible: false, period: $0)
            }
            let hasAccess = hasAccess(festivalId: festivalId, districtId: districtId, visibility: record.item.visibility , user: user)
            return .init(routeId: record.id, isVisible: hasAccess, period: $0)
        }
        return items
    }
}



