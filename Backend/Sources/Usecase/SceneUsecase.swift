import Foundation
import Dependencies
import Shared

// MARK: - Dependencies
enum SceneUsecaseKey: DependencyKey {
    static let liveValue: SceneUsecaseProtocol = SceneUsecase()
}

// MARK: - SceneUsecaseProtocol
protocol SceneUsecaseProtocol: Sendable {
    func fetchLaunchFestivalPack(festivalId: String, user: UserRole) async throws -> LaunchFestivalPack
    func fetchLaunchDistrictPack(districtId: String, user: UserRole, now: SimpleDate) async throws -> LaunchDistrictPack
    func fetchLoginPack(user: UserRole) async throws -> LoginPack
}

extension SceneUsecaseProtocol {
    func fetchLaunchDistrictPack(districtId: String, user: UserRole) async throws -> LaunchDistrictPack {
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

    func fetchLaunchFestivalPack(festivalId: String, user: UserRole) async throws -> LaunchFestivalPack {
        let isAdmin = (user != .guest)

        guard let festival = try await festivalRepository.get(id: festivalId) else {
            throw Error.notFound("Festival \(festivalId) が見つかりません")
        }

        if isAdmin {
            return try await fetchAdminLaunchPack(festival: festival)
        } else {
            return try await fetchUserLaunchPack(festival: festival)
        }
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
    private func fetchUserLaunchPack(festival: Festival) async throws -> LaunchFestivalPack {
        async let districts = districtRepository.query(by: festival.id)
        async let locations = floatLocationRepository.query(by: festival.id)
        let periods = try await fetchLatestPeriods(festivalId: festival.id)

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
    private func fetchLatestPeriods(festivalId: String) async throws -> [Period] {
        let nowYear = SimpleDate.now.year

        async let nextYearPeriods = periodRepository.query(by: festivalId, year: nowYear + 1)
        async let currentYearPeriods = periodRepository.query(by: festivalId, year: nowYear)

        let (nextYear, currentYear) = try await (nextYearPeriods, currentYearPeriods)

        if !nextYear.isEmpty {
            return nextYear
        } else if !currentYear.isEmpty {
            return currentYear
        } else {
            return []
        }
    }

    func fetchLaunchDistrictPack(districtId: String, user: UserRole, now: SimpleDate) async throws -> LaunchDistrictPack {
        let district = try await getDistrict(districtId)
        async let performances = performanceRepository.query(by: districtId)
        
        let routesAll: [Route] = try await {
            let nextYear = now.year + 1
            let nextYearRoutes = try await routeRepository.query(by: districtId, year: nextYear)
            if nextYearRoutes.isEmpty {
                return try await routeRepository.query(by: districtId, year: now.year)
            } else {
                return nextYearRoutes
            }
        }()

        let filtered = routesAll.filter { isVisible(visibility: $0.visibility, user: user, district: district) }
        guard let currentRouteId = filtered.first?.id else {
            throw Error.notFound("利用可能なルートが見つかりません")
        } // TODO: Currentのロジック

        let points = try await pointRepository.query(by: currentRouteId)

        return .init(
            performances: try await performances,
            routes: filtered,
            points: points,
            currentRouteId: currentRouteId
        )
    }

    func fetchLoginPack(user: UserRole) async throws -> LoginPack {
        let festivalId: Festival.ID = try await {
            switch user {
            case .headquarter(let festivalId):
                return festivalId
            case .district(let districtId):
                guard let district = try await districtRepository.get(id: districtId) else { throw Error.badRequest("IDが不正です") }
                return district.festivalId
            case .guest:
                throw Error.unauthorized("アクセス権限がありません。")
            }
        }()
        async let periods = periodRepository.query(by: festivalId)
        async let checkpoints = checkpointRepository.query(by: festivalId)
        async let hazardSections = hazardRepository.query(by: festivalId)
        return try await .init(checkpoints: checkpoints, hazardSections: hazardSections, periods: periods)
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
