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
    func get(id: String, user: UserRole) async throws -> RoutePack
    func query(by districtId: String, type: RouteQueryType, now: SimpleDate, user: UserRole) async throws -> [Route]
    func post(districtId: String, pack: RoutePack, user: UserRole) async throws -> RoutePack
    func put(id: String, pack: RoutePack, user: UserRole) async throws -> RoutePack
    func delete(id: String, user: UserRole) async throws
}

extension RouteUsecaseProtocol {
    func query(by districtId: String, type: RouteQueryType, user: UserRole) async throws -> [Route] {
        try await query(by: districtId, type: type, now: .now, user: user)
    }
}

// MARK: - RouteUsecase
struct RouteUsecase: RouteUsecaseProtocol {
    @Dependency(RouteRepositoryKey.self) var routeRepository
    @Dependency(PeriodRepositoryKey.self) var periodRepository
    @Dependency(DistrictRepositoryKey.self) var districtRepository
    @Dependency(FestivalRepositoryKey.self) var festivalRepository
    @Dependency(PointRepositoryKey.self) var pointRepository
    @Dependency(PassageRepositoryKey.self) var passageRepository
    
    func get(id: String, user: UserRole) async throws -> RoutePack {
        guard let route = try await routeRepository.get(id: id) else {
            throw Error.notFound("指定されたルートが見つかりません")
        }
        let district = try await getDistrict(route.districtId)
        let isVisible = isVisible(visibility: route.visibility, user: user, district: district)
        if !isVisible {
            throw Error.forbidden("アクセス権限がありせん。このルートは非公開です。")
        }
        let points = try await pointRepository.query(by: route.id)
        let passages = try await passageRepository.query(by: route.id)
        
        return .init(route: route, points: points, passages: passages)
    }
    
    func query(by districtId: String, type: RouteQueryType, now: SimpleDate, user: UserRole) async throws -> [Route] {
        let district = try await getDistrict(districtId)
        let routes = try await {
            switch type {
            case .all:
                return try await routeRepository.query(by: districtId)
            case .year(let year):
                return try await routeRepository.query(by: districtId, year: year)
            case .latest:
                let (routes, _) = try await LatestPeriodRouteResolver.fetchLatestRoutes(
                    districtId: districtId,
                    festivalId: district.festivalId,
                    nowYear: now.year,
                    periodRepository: periodRepository,
                    routeRepository: routeRepository
                )
                return routes
            }
        }()
        let filtered = routes.filter{
            isVisible(visibility: $0.visibility, user: user, district: district)
        }
        return filtered
    }
    
    func post(districtId: String, pack: RoutePack, user: UserRole) async throws -> RoutePack {
        guard districtId == user.id,
              pack.route.districtId == user.id else {
            throw Error.unauthorized("アクセス権限がありません")
        }
        let district = try await getDistrict(districtId)
        try await ensureRouteEditable(district: district)
        let reindexedPoints = pack.points.reindexed()
        let reindexedPassages = pack.passages.reindexed()
        try pack.points.validate()
        let oldPoints = try await pointRepository.query(by: pack.route.id)
        let oldPassages = try await passageRepository.query(by: pack.route.id)
        let route = try await routeRepository.post(pack.route)
        let points = try await oldPoints.update(with: reindexedPoints, separateDeleteAndUpdate: true, repository: pointRepository)
        let passages = try await oldPassages.update(with: reindexedPassages, separateDeleteAndUpdate: true, repository: passageRepository)
        return .init(route: route, points: points, passages: passages)
    }
    
    func put(id: String, pack: RoutePack, user: UserRole) async throws -> RoutePack {
        guard let old = try await routeRepository.get(id: id) else {
            throw Error.notFound("指定されたルートが見つかりません")
        }
        guard pack.route.districtId == user.id,
              old.districtId == user.id else {
            throw Error.unauthorized("アクセス権限がありません")
        }
        let district = try await getDistrict(old.districtId)
        try await ensureRouteEditable(district: district)
        let reindexedPoints = pack.points.reindexed()
        let reindexedPassages = pack.passages.reindexed()
        try pack.points.validate()
        let oldPoints = try await pointRepository.query(by: pack.route.id)
        let oldPassages = try await passageRepository.query(by: pack.route.id)
        let route = try await routeRepository.post(pack.route)
        let points = try await oldPoints.update(with: reindexedPoints, separateDeleteAndUpdate: true, repository: pointRepository)
        let passages = try await oldPassages.update(with: reindexedPassages, separateDeleteAndUpdate: true, repository: passageRepository)
        return .init(route: route, points: points, passages: passages)
    }
    
    func delete(id: String, user: UserRole) async throws {
        guard let old = try await routeRepository.get(id: id) else {
            throw Error.notFound("指定されたルートが見つかりません")
        }
        if old.districtId != user.id {
            throw Error.unauthorized("アクセス権限がありません")
        }
        let district = try await getDistrict(old.districtId)
        try await ensureRouteEditable(district: district)
        try await routeRepository.delete(id: id)
        _ = try await pointRepository.delete(by: id)
        _ = try await passageRepository.delete(by: id)
        return
    }
}

extension RouteUsecase {
    private func isVisible(visibility: Visibility, user: UserRole, district: District) -> Bool {
        if visibility == .admin {
            switch user {
            case .guest:
                false
            case .district(let id):
                id == district.id
            case .headquarter(let id):
                id == district.festivalId
            }
        } else {
            true
        }
    }
    
    private func getDistrict(_ id: District.ID) async throws -> District {
        guard let district = try await districtRepository.get(id: id) else {
            throw Error.notFound("指定された地区が見つかりません")
        }
        return district
    }

    private func ensureRouteEditable(district: District) async throws {
        guard district.isEditable else { return }
        guard let festival = try await festivalRepository.get(id: district.festivalId) else {
            throw Error.notFound("所属する祭典が見つかりません")
        }
        throw Error.forbidden("\(festival.subname)編集中のためRoute更新はできません")
    }
    
    private func removeTimeIfNeeded(district: District, points: [Point], user: UserRole) -> [Point] {
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
                return points.map{
                    var point = $0
                    point.time = nil
                    return point
                }
            }
        }
        return points
    }
}

enum RouteQueryType {
    case all
    case year(Int)
    case latest
}
