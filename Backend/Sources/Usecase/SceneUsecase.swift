import Foundation
import Dependencies
import Shared

// MARK: - Dependencies
enum SceneUsecaseKey: DependencyKey {
    static let liveValue: SceneUsecaseProtocol = SceneUsecase()
}

// MARK: - SceneUsecaseProtocol
protocol SceneUsecaseProtocol: Sendable {
    func fetchLaunchFestivalPack(festivalId: Festival.ID, user: UserRole, now: Date) async throws -> LaunchFestivalPack
    func fetchLaunchFestivalPack(districtId: District.ID, user: UserRole, now: Date) async throws -> LaunchFestivalPack
    func fetchLaunchDistrictPack(districtId: District.ID, user: UserRole, now: Date) async throws -> LaunchDistrictPack
}

extension SceneUsecaseProtocol {
    func fetchLaunchFestivalPack(festivalId: Festival.ID, user: UserRole) async throws -> LaunchFestivalPack {
        try await fetchLaunchFestivalPack(festivalId: festivalId, user: user, now: .now)
    }
    
    func fetchLaunchFestivalPack(districtId: District.ID, user: UserRole) async throws -> LaunchFestivalPack {
        try await fetchLaunchFestivalPack(districtId: districtId, user: user, now: .now)
    }
    
    func fetchLaunchDistrictPack(districtId: District.ID, user: UserRole) async throws -> LaunchDistrictPack {
        try await fetchLaunchDistrictPack(districtId: districtId, user: user, now: .now)
    }
}

// MARK: - SceneUsecase
struct SceneUsecase: SceneUsecaseProtocol {
    @Dependency(FestivalRepositoryKey.self) var festivalRepository
    @Dependency(DistrictRepositoryKey.self) var districtRepository
    @Dependency(PeriodRepositoryKey.self) var periodRepository
    @Dependency(LocationRepositoryKey.self) var floatLocationRepository
    @Dependency(CheckpointRepositoryKey.self) var checkpointRepository
    @Dependency(HazardSectionRepositoryKey.self) var hazardRepository
    @Dependency(PerformanceRepositoryKey.self) var performanceRepository
    @Dependency(RouteRepositoryKey.self) var routeRepository
    @Dependency(PointRepositoryKey.self) var pointRepository

    func fetchLaunchFestivalPack(festivalId: Festival.ID, user: UserRole, now: Date) async throws -> LaunchFestivalPack {
        let isAdmin = (user != .guest)

        guard let festival = try await festivalRepository.get(id: festivalId) else {
            throw Error.notFound("Festival \(festivalId) が見つかりません")
        }

        if isAdmin {
            return try await fetchAdminLaunchPack(festival: festival)
        } else {
            return try await fetchUserLaunchPack(festival: festival, now: now)
        }
    }
    
    func fetchLaunchFestivalPack(districtId: District.ID, user: UserRole, now: Date) async throws -> LaunchFestivalPack {
        guard let district = try await districtRepository.get(id: districtId) else {
            throw Error.notFound("District \(districtId) が見つかりません")
        }
        return try await fetchLaunchFestivalPack(festivalId: district.festivalId, user: user, now: now)
    }

    // MARK: - Private: 管理者用
    private func fetchAdminLaunchPack(festival: Festival) async throws -> LaunchFestivalPack {
        async let districts = districtRepository.query(by: festival.id)
        async let periods = periodRepository.query(by: festival.id) // 過去全て
        async let locations = floatLocationRepository.query(by: festival.id)
        async let checkpoints = checkpointRepository.query(by: festival.id)
        async let hazardSections = hazardRepository.query(by: festival.id)

        return LaunchFestivalPack(
            festival: festival,
            districts: try await districts,
            periods: try await periods,
            locations: try await locations,
            checkpoints: try await checkpoints,
            hazardSections: try await hazardSections
        )
    }

    // MARK: - Private: 一般ユーザー用
    private func fetchUserLaunchPack(festival: Festival, now: Date) async throws -> LaunchFestivalPack {
        async let districts = districtRepository.query(by: festival.id)
        async let locations = floatLocationRepository.query(by: festival.id)
        let periods = try await fetchLatestPeriods(festivalId: festival.id, now: now)

        return LaunchFestivalPack(
            festival: festival,
            districts: try await districts,
            periods: periods,
            locations: try await locations,
            checkpoints: [],
            hazardSections: []
        )
    }

    // MARK: - Private: latest 年取得
    private func fetchLatestPeriods(festivalId: String, now: Date) async throws -> [Period] {
        let nowYear = SimpleDate.from(now).year

        async let nextYearPeriods = periodRepository.query(by: festivalId, year: nowYear + 1)
        async let currentYearPeriods = periodRepository.query(by: festivalId, year: nowYear)

        let (nextYear, currentYear) = try await (nextYearPeriods, currentYearPeriods)

        return currentYear + nextYear
    }

    func fetchLaunchDistrictPack(districtId: District.ID, user: UserRole, now: Date) async throws -> LaunchDistrictPack {
        let district = try await getDistrict(districtId)
        async let performances = performanceRepository.query(by: districtId)
        
        let (routes, periods): ([Route], [Period]) = try await {
            let nowYear = SimpleDate.from(now).year
            let nextYear = nowYear + 1
            let nextYearRoutes = try await routeRepository.query(by: districtId, year: nextYear)
            if nextYearRoutes.isEmpty {
                async let routes = routeRepository.query(by: districtId, year: nowYear)
                async let periods = periodRepository.query(by: district.festivalId, year: nowYear)
                return (routesAll: try await routes, periods: try await periods)
            } else {
                let periods = try await periodRepository.query(by: district.festivalId, year: nextYear)
                return (routes: nextYearRoutes, periods: periods)
            }
        }()

        let filtered = routes.filter { isVisible(visibility: $0.visibility, user: user, district: district) }
        
        let currentPeriod: Period? = {
            if let between = periods.first(where: { $0.contains(now) }){
                between
            } else if let before = periods.sorted().first(where: { $0.before(now) }) {
                before
            } else {
                periods.first
            }
        }()
        
        if let currentPeriod ,
            let currentRoute = filtered.first(where: { currentPeriod.id == $0.periodId }) {
            let points = try await pointRepository.query(by: currentRoute.id)
            return .init(
                performances: try await performances,
                routes: filtered,
                points: points,
                currentRouteId: currentRoute.id
            )
        }
        return .init(
            performances: try await performances,
            routes: filtered,
            points: [],
            currentRouteId: nil
        )
    }
}

// MARK: - Helpers (copied logic from RouteUsecase)
extension SceneUsecase {
    fileprivate func isVisible(visibility: Visibility, user: UserRole, district: District) -> Bool {
        if visibility == .admin {
            switch user {
            case .guest:
                return false
            case .district(let id):
                return id == district.id
            case .headquarter(let id):
                return id == district.festivalId
            }
        } else {
            return true
        }
    }

    fileprivate func getDistrict(_ id: District.ID) async throws -> District {
        guard let district = try await districtRepository.get(id: id) else {
            throw Error.notFound("指定された地区が見つかりません")
        }
        return district
    }
}
