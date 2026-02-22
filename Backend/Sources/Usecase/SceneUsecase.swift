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
    @Dependency(PassageRepositoryKey.self) var passageRepository
    
    // MARK: - LaunchFestival
    func fetchLaunchFestivalPack(festivalId: Festival.ID, user: UserRole, now: Date) async throws -> LaunchFestivalPack {
        let isAdmin = (user != .guest)

        guard let festival = try await festivalRepository.get(id: festivalId) else {
            throw Error.notFound("Festival \(festivalId) が見つかりません")
        }

        if isAdmin {
            return try await fetchAdminLaunchPack(festival: festival, user: user, now: now)
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

    // MARK: Admin
    private func fetchAdminLaunchPack(festival: Festival, user: UserRole, now: Date) async throws -> LaunchFestivalPack {
        async let districts = districtRepository.query(by: festival.id)
        async let checkpoints = checkpointRepository.query(by: festival.id)
        async let hazardSections = hazardRepository.query(by: festival.id)
        let periods = try await periodRepository.query(by: festival.id) // 過去全て

        let locations: [FloatLocation]
        if LocationPublicAccess.isPublic(now: now, periods: periods) {
            locations = try await floatLocationRepository.query(by: festival.id)
        } else if case let .district(districtId) = user {
            let location = try await floatLocationRepository.get(festivalId: festival.id, districtId: districtId)
            locations = location.map { [$0] } ?? []
        } else {
            locations = []
        }

        return LaunchFestivalPack(
            festival: festival,
            districts: try await districts,
            periods: periods,
            locations: locations,
            checkpoints: try await checkpoints,
            hazardSections: try await hazardSections
        )
    }

    // MARK: Public
    private func fetchUserLaunchPack(festival: Festival, now: Date) async throws -> LaunchFestivalPack {
        async let districts = districtRepository.query(by: festival.id)
        let periods = try await LatestPeriodRouteResolver.fetchLatestPeriods(
            festivalId: festival.id,
            nowYear: SimpleDate.from(now).year,
            periodRepository: periodRepository
        )
        let locations: [FloatLocation]
        if LocationPublicAccess.isPublic(now: now, periods: periods) {
            locations = try await floatLocationRepository.query(by: festival.id)
        } else {
            locations = []
        }

        return LaunchFestivalPack(
            festival: festival,
            districts: try await districts,
            periods: periods,
            locations: locations,
            checkpoints: [],
            hazardSections: []
        )
    }

    // MARK: - LaunchDistrict
    func fetchLaunchDistrictPack(districtId: District.ID, user: UserRole, now: Date) async throws -> LaunchDistrictPack {
        let district = try await getDistrict(districtId)
        async let performances = performanceRepository.query(by: districtId)
        
        let (routes, periods) = try await LatestPeriodRouteResolver.fetchLatestRoutes(
            districtId: districtId,
            festivalId: district.festivalId,
            nowYear: SimpleDate.from(now).year,
            periodRepository: periodRepository,
            routeRepository: routeRepository
        )

        let filteredRoutes = routes.filter { isVisible(visibility: $0.visibility, user: user, district: district) }

        let routeWithPeriod: [(route: Route, period: Period)] = filteredRoutes.compactMap { route in
            if let period = periods.first(where: { $0.id == route.periodId }) {
                return (route, period)
            }
            return nil
        }

        // 優先度順にソート
        
        let sorted = routeWithPeriod.sorted {
            $0.period.priority(now: now) < $1.period.priority(now: now)
        }

        let currentRoute = sorted.first?.route
        let points = currentRoute != nil ? try await pointRepository.query(by: currentRoute!.id) : []
        let passages = currentRoute != nil ? try await passageRepository.query(by: currentRoute!.id) : []

        return .init(
            performances: try await performances,
            routes: filteredRoutes,
            points: points,
            passages: passages,
            currentRouteId: currentRoute?.id
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
