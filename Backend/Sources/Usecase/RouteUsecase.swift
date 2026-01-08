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
    func query(by districtId: String, user: UserRole) async throws -> [Route]
    func get(id: String, user: UserRole) async throws -> Route
    func post(districtId: String, route: Route, user: UserRole) async throws -> Route
    func put(id: String, route: Route, user: UserRole) async throws -> Route
    func getAllRouteIds(user: UserRole) async throws -> [String]
    func delete(id: String, user: UserRole) async throws
}

// MARK: - RouteUsecase
struct RouteUsecase: RouteUsecaseProtocol {
    @Dependency(RouteRepositoryKey.self) var routeRepository
    @Dependency(DistrictRepositoryKey.self) var districtRepository
    @Dependency(LocationRepositoryKey.self) var locationRepository
    @Dependency(FestivalRepositoryKey.self) var festivalRepository
    
    func query(by districtId: String, user: UserRole) async throws -> [Route] {
        guard let district = try await districtRepository.get(id: districtId) else {
            throw Error.notFound("指定された地区が見つかりません")
        }
        if district.visibility == .admin {
            let hasAccess: Bool
            switch user {
            case .guest:
                hasAccess = false
            case .district(let id):
                hasAccess = id == districtId
            case .headquarter(let id):
                hasAccess = id == district.festivalId
            }
            
            if !hasAccess {
                throw Error.unauthorized("アクセス権限がありません")
            }
        }
        let routes = try await routeRepository.query(by: districtId)
        return routes
    }
    
    func get(id: String, user: UserRole) async throws -> Route {
        guard let route = try await routeRepository.get(id: id) else {
            throw Error.notFound("指定されたルートが見つかりません")
        }
        guard let district = try await districtRepository.get(id: route.districtId) else {
            throw Error.notFound("指定された地区が見つかりません")
        }
        if district.visibility == .admin {
            let hasAccess: Bool
            switch user {
            case .guest:
                hasAccess = false
            case .district(let districtId):
                hasAccess = districtId == district.id
            case .headquarter(let festivalId):
                hasAccess = festivalId == district.festivalId
            }
            if !hasAccess {
                throw Error.unauthorized("アクセス権限がありません")
            }
        }
        if district.visibility == .route {
            let hasAccess: Bool
            switch user {
            case .guest:
                hasAccess = false
            case .district(let districtId):
                hasAccess = districtId == district.id
            case .headquarter(let festivalId):
                hasAccess = festivalId == district.festivalId
            }
            if !hasAccess {
                return removeTime(route)
            }
        }
        return route
    }
    
    func post(districtId: String, route: Route, user: UserRole) async throws -> Route {
        guard districtId == user.id,
              route.districtId == user.id else {
            throw Error.unauthorized("アクセス権限がありません")
        }
        
        let result = try await routeRepository.post(route)
        return result
    }
    
    func put(id: String, route: Route, user: UserRole) async throws -> Route {
        guard let old = try await routeRepository.get(id: id) else {
            throw Error.notFound("指定されたルートが見つかりません")
        }
        guard route.districtId == user.id,
              old.districtId == user.id else {
            throw Error.unauthorized("アクセス権限がありません")
        }
        
        let result = try await routeRepository.put(route)
        return result
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
    
    func getAllRouteIds(user: UserRole) async throws -> [String] {
        guard case let .headquarter(festivalId) = user else {
            throw Error.unauthorized("アクセス権限がありません")
        }
        
        let districts = try await districtRepository.query(by: festivalId)
        
        if districts.isEmpty {
            throw Error.unauthorized("アクセス権限がありません")
        }
        
        var ids: [String] = []
        
        for district in districts {
            let routes = try await routeRepository.query(by: district.id)
            ids.append(contentsOf: routes.map { $0.id })
        }
        
        return ids
    }
}

extension RouteUsecase {
    private func removeTime(_ route: Route) -> Route {
        var modifiedRoute = route
        modifiedRoute.start = SimpleTime(hour: 0, minute: 0)
        modifiedRoute.goal = SimpleTime(hour: 0, minute: 0)
        modifiedRoute.points = route.points.map { point in
            var modifiedPoint = point
            modifiedPoint.time = nil
            return modifiedPoint
        }
        return modifiedRoute
    }
    
    private func removeTimeIfNeeded(district: District, route: Route, user: UserRole) -> Route {
        if district.visibility == .route {
            let hasAccess: Bool
            switch user {
            case .guest:
                hasAccess = false
            case .district(let id):
                hasAccess = id == district.id
            case .headquarter(let festivalId):
                hasAccess = festivalId == district.festivalId
            }
            
            if !hasAccess {
                return removeTime(route)
            }
        }
        return route
    }
    
    private func selectCurrentItem(items: [Route], now: Date) -> Route? {
        if items.isEmpty {
            return nil
        }
        
        // 昇順ソート（古い → 新しい）
        let sortedItems = items.sorted { a, b in
            let dateA = convertDate(date: a.date, time: a.start)
            let dateB = convertDate(date: b.date, time: b.start)
            return dateA < dateB
        }
        
        for item in sortedItems {
            let start = convertDate(date: item.date, time: item.start)
            let goal = convertDate(date: item.date, time: item.goal)
            let diffOfStart = start.timeIntervalSince(now)
            let diffOfGoal = goal.timeIntervalSince(now)
            if diffOfStart <= 0 && diffOfGoal > 0 {
                return item
            }
            if diffOfStart > 0 {
                return item
            }
        }
        return sortedItems.first
    }
    
    private func convertDate(date: SimpleDate, time: SimpleTime) -> Date {
        var components = DateComponents()
        components.year = date.year
        components.month = date.month
        components.day = date.day
        components.hour = time.hour
        components.minute = time.minute
        components.second = 0
        return Calendar.current.date(from: components) ?? Date()
    }
    
    private func getForPublic(district: District, festival: Festival, now: Date = Date()) async throws -> FloatLocation {
        // TODO: Period修正
        throw Error.unauthorized("アクセス権限がありません")
//        guard festival.periods.first(where: { $0.contains(now) }) != nil else { throw Error.unauthorized("アクセス権限がありません") }
        guard let location = try await locationRepository.get(id: district.id) else {
            throw Error.notFound("位置情報が見つかりません")
        }
        return location
    }
    
    private func getForAdmin(districtId: String) async throws -> FloatLocation {
        guard let location = try await locationRepository.get(id: districtId) else {
            throw Error.notFound("位置情報が見つかりません")
        }
        return location
    }
}

