//
//  SceneUsecase.swift
//  matool-backend
//
//  Created by 松下和也 on 2025/12/20.
//

import Dependencies
import Shared
import Foundation

enum SceneUsecaseKey: DependencyKey {
    static let liveValue: SceneUsecaseProtocol = SceneUsecase()
}

protocol SceneUsecaseProtocol: Sendable {
    func getAllRouteIds(user: UserRole) async throws -> [String]
    func getMapRoute(districtId: String, user: UserRole, now: Date) async throws -> CurrentResponse
    func getMapRoute(districtId: String, user: UserRole, periodId: String, now: Date) async throws -> CurrentResponse
}

struct SceneUsecase: SceneUsecaseProtocol {
    private enum Temporal: Equatable {
        case before(TimeInterval)
        case between
        case not

        func isPubliclyVisible(leadTime: TimeInterval = threthold) -> Bool {
            switch self {
            case .between:
                return true
            case .before(let seconds):
                return seconds <= leadTime
            case .not:
                return false
            }
        }
    }
    
    @Dependency(RouteRepositoryKey.self) var routeRepository
    @Dependency(DistrictRepositoryKey.self) var districtRepository
    @Dependency(PeriodRepositoryKey.self) var periodRepository
    @Dependency(LocationRepositoryKey.self) var locationRepository
    @Dependency(FestivalRepositoryKey.self) var festivalRepository
    
    func getAllRouteIds(user: UserRole) async throws -> [String] {
        guard case let .headquarter(festivalId) = user else {
            throw Error.unauthorized("アクセス権限がありません")
        }

        let districts = try await districtRepository.query(by: festivalId)

        if districts.isEmpty {
            throw Error.unauthorized("アクセス権限がありません")
        }

        return try await withThrowingTaskGroup(of: [String].self) { group in
            for district in districts {
                group.addTask {
                    let routes = try await routeRepository.query(by: district.id)
                    return routes.map { $0.id }
                }
            }
            var ids: [String] = []
            for try await chunk in group {
                ids.append(contentsOf: chunk)
            }
            return ids
        }
    }
    
    func getMapRoute(districtId: String, user: UserRole, now: Date = Date()) async throws -> CurrentResponse {
        // Fetch district first to validate existence
        guard let district = try await districtRepository.get(id: districtId) else {
            throw Error.notFound("指定された地区が見つかりません")
        }

        // Fetch related entities in parallel
        let year = SimpleDate.from(now).year
        async let periodTask = periodRepository.query(festivalId: district.festivalId, year: year)
        async let festivalTask = festivalRepository.get(id: district.festivalId)
        async let routeTask = routeRepository.query(by: districtId)

        let periods = try await periodTask
        guard let festival = try await festivalTask else {
            throw Error.notFound("データが見つかりません")
        }
        let records = try await routeTask
        let festivalId = festival.id
        let districtId = district.id

        var message: String? = nil
        var items: [CurrentResponse.RouteItem] = []
        var temporal: Temporal = .not
        var detail: CurrentResponse.RouteDetail? = nil
        
        do {
            let (route, period): (Route, Period)
            ((route, period, temporal), items) = try resolveCurrentRoutes(records: records, periods: periods, now: now, festivalId: festivalId, districtId: districtId, user: user)
            detail = .init(
                period: period,
                route: route,
                checkpoints: festival.checkpoints,
                performances: district.performances
            )
        } catch let error as Error {
            message = error.localizedDescription
        }
        
        var location: FloatLocation?
        do {
            location = try await getLocation(
                user: user,
                festivalId: festival.id,
                districtId: district.id,
                temporal: temporal
            )
        } catch {
            let text = error.localizedDescription
            message = message.map { $0 + "\n" + text } ?? text
        }

        return CurrentResponse(
            districtId: district.id,
            districtName: district.name,
            items: items,
            detail: detail,
            location: location,
            message: message
        )
    }
    
    func getMapRoute(districtId: String, user: UserRole, periodId: String, now: Date = Date()) async throws -> CurrentResponse {
        // Fetch district first to validate existence and to get festivalId
        guard let district = try await districtRepository.get(id: districtId) else {
            throw Error.notFound("指定された地区が見つかりません")
        }

        // Fetch related entities in parallel
        let year = SimpleDate.from(now).year
        async let routeTask = routeRepository.query(by: district.id)
        async let periodTask = periodRepository.query(festivalId: district.festivalId, year: year)
        async let festivalTask = festivalRepository.get(id: district.festivalId)

        let periods = try await periodTask
        guard let festival = try await festivalTask else {
            throw Error.notFound("指定された地区が見つかりません")
        }
        let routes = try await routeTask
        let records = try await routeTask
        
        var detail: CurrentResponse.RouteDetail? = nil
        
        if let period = periods.first(where: { $0.id == periodId }),
           let route = routes.first(where: { $0.periodId == periodId })?.item {
            detail = .init(
                period: period,
                route: route,
                checkpoints: festival.checkpoints,
                performances: district.performances
            )
        }
              
        
        let festivalId = festival.id
        let districtId = district.id

        var message: String? = nil
        var items: [CurrentResponse.RouteItem] = []
        var temporal: Temporal = .not
        
        do {
            ((_, _, temporal), items) = try resolveCurrentRoutes(records: records, periods: periods, now: now, festivalId: festivalId, districtId: districtId, user: user)
        } catch let error as Error {
            message = error.localizedDescription
        }
        
        var location: FloatLocation?
        do {
            location = try await getLocation(
                user: user,
                festivalId: festival.id,
                districtId: district.id,
                temporal: temporal
            )
        } catch {
            let text = error.localizedDescription
            message = message.map { $0 + "\n" + text } ?? text
        }

        return CurrentResponse(
            districtId: district.id,
            districtName: district.name,
            items: items,
            detail: detail,
            location: location,
            message: message
        )
    }
}

extension SceneUsecase {
    private func resolveCurrentRoutes(records: [RouteRecord], periods: [Period], now: Date, festivalId: String, districtId: String, user: UserRole) throws -> (selected: (Route, Period, Temporal), filtered: [CurrentResponse.RouteItem]) {
        let routeByPeriodId = Dictionary(
            uniqueKeysWithValues: records.map { ($0.periodId, $0.item) }
        )
        
        var items: [CurrentResponse.RouteItem] = []
        var pairs: [(Route, Period)] = []
        for period in periods {
            guard let route = routeByPeriodId[period.id],
                  hasAccess(festivalId: festivalId, districtId: districtId, visibility: route.visibility, user: user) else {
                items.append(.init(routeId: nil, isVisible: false, period: period))
                continue
            }
            pairs.append((route, period))
        }

        let sorted = pairs.sorted { $0.1 < $1.1 }
        
        for (route, period) in sorted {
            let start = Date.combine(date: period.date, time: route.startTime ?? period.start)
            let goal = Date.combine(date: period.date, time: route.endTime ?? period.end)
            let diffOfStart = start.timeIntervalSince(now)
            let diffOfGoal = goal.timeIntervalSince(now)
            if diffOfStart <= 0 && diffOfGoal > 0 {
                return ((route, period, .between), items)
            }
            if diffOfStart > 0 {
                return ((route, period, .before(diffOfStart)), items)
            }
        }
        if let first = sorted.first {
            return ((first.0, first.1, .not), items)
        } else {
            throw Error.notFound("経路が見つかりませんでした。")
        }
    }
    
    // Location取得
    private func getLocation(user: UserRole, festivalId: String, districtId: String, temporal: Temporal) async throws -> FloatLocation {
        if hasAccess(festivalId: festivalId, districtId: districtId, user: user) || temporal.isPubliclyVisible() {
            guard let location = try await locationRepository.get(id: districtId) else {
                throw Error.notFound("位置情報の配信を一時的に中断しています。")
            }
            return location
        } else {
            throw Error.forbidden("現在は位置情報を公開していません。開始\(threthold)分前以降に準備が整い次第、配信を開始します。")
        }
    }
}

