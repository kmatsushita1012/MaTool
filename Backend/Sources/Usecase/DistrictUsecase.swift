//
//  DistrictUsecase.swift
//  Backend
//
//  Created by 松下和也 on 2025/11/21.
//

import Dependencies
import Shared

// MARK: - Dependencies
enum DistrictUsecaseKey: DependencyKey {
    static let liveValue: DistrictUsecaseProtocol = DistrictUsecase()
}

// MARK: - DistrictUsecaseProtocol
protocol DistrictUsecaseProtocol: Sendable {
    func query(by regionId: String) async throws -> [District]
    func get(_ id: String) async throws -> DistrictPack
    func post(user: UserRole, headquarterId: String, newDistrictName: String, email: String) async throws -> DistrictPack
    func put(id: String, item: DistrictPack, user: UserRole) async throws -> DistrictPack
    func put(id: String, district: District, user: UserRole) async throws -> District
}

// MARK: - DistrictUsecase
struct DistrictUsecase: DistrictUsecaseProtocol {
    @Dependency(DistrictRepositoryKey.self) var repository
    @Dependency(RouteRepositoryKey.self) var routeRepository
    @Dependency(PeriodRepositoryKey.self) var periodRepository
    @Dependency(FestivalRepositoryKey.self) var festivalRepository
    @Dependency(PerformanceRepositoryKey.self) var peformanceRepository
    @Dependency(AuthManagerFactoryKey.self) var managerFactory
    
    func query(by regionId: String) async throws -> [District] {
        let items = try await repository.query(by: regionId)
        return items
    }
    
    func get(_ id: String) async throws -> DistrictPack {
        let district = try await repository.get(id: id)
        guard let district else { throw Error.notFound("指定された地区が見つかりません") }
        
        let performances = try await peformanceRepository.query(by: id)
        
        return .init(district: district, performances: performances)
    }
    
    func post(user: UserRole, headquarterId: String, newDistrictName: String, email: String) async throws -> DistrictPack {
        // 認可チェック
        guard case let .headquarter(id) = user, headquarterId == id  else {
            throw Error.unauthorized()
        }

        // 所属する祭典の取得
        guard let festival = try await festivalRepository.get(id: id) else {
            throw Error.notFound("所属する祭典が見つかりません")
        }

        // ID生成 & 重複確認
        let districtId = makeDistrictId(newDistrictName, festival: festival)
        if let _ = try await repository.get(id: districtId) {
            throw Error.conflict("この名前はすでに登録されています")
        }

        // 招待処理
        let _ = try await managerFactory().create(
            username: districtId,
            email: email
        )

        // District生成
        let item = District(
            id: districtId,
            name: newDistrictName,
            festivalId: headquarterId,
        )

        let district = try await repository.post(item: item)
        return .init(district: district, performances: [])
    }
    // District権限
    func put(id: String, item: DistrictPack, user: UserRole) async throws -> DistrictPack {
        guard case let .district(districtId) = user, id == districtId else {
            throw Error.unauthorized("アクセス権限がありません")
        }
        // 現在のDistrictを取得して、変更可能なプロパティのみ反映
        guard let current = try await repository.get(id: id) else {
            throw Error.notFound("指定された地区が見つかりません")
        }
        let mergedDistrict = mergeForDistrictRole(current: current, incoming: item.district)
        let district = try await repository.put(id: id, item: mergedDistrict)
        if current.visibility != district.visibility {
            try await applyVisibilityToLatestYearRoutes(
                districtId: id,
                festivalId: district.festivalId,
                visibility: district.visibility,
                nowYear: SimpleDate.now.year
            )
        }
        
        let oldPerformances = try await peformanceRepository.query(by: districtId)
        let performances = try await oldPerformances.update(with: item.performances, repository: peformanceRepository)
        
        return .init(district: district, performances: performances)
    }
    
    // HQ権限
    func put(id: String, district: District, user: UserRole) async throws -> District {
        guard case let .headquarter(hqId) = user, district.festivalId == hqId, id == district.id else {
            throw Error.unauthorized("アクセス権限がありません")
        }
        // 現在のDistrictを取得して、HQが変更可能なプロパティのみ反映
        guard let current = try await repository.get(id: id) else {
            throw Error.notFound("指定された地区が見つかりません")
        }
        let merged = mergeForHQRole(current: current, incoming: district)
        let result = try await repository.put(id: id, item: merged)
        
        return result
    }
}

extension DistrictUsecase {
    // District権限: order, group, isEditable は変更不可。それ以外の可変プロパティのみ反映
    private func mergeForDistrictRole(current: District, incoming: District) -> District {
        var result = current
        // 許可フィールドを反映
        result.name = incoming.name
        result.description = incoming.description
        result.base = incoming.base
        result.area = incoming.area
        result.image = incoming.image
        result.visibility = incoming.visibility

        return result
    }
    
    // HQ権限: order, group, isEditable のみ変更可能。他は current を維持
    private func mergeForHQRole(current: District, incoming: District) -> District {
        var result = current
        // HQ権限は order / group / isEditable のみ変更可能。他は current を維持
        result.order = incoming.order
        result.group = incoming.group
        result.isEditable = incoming.isEditable
        return result
    }

    private func makeDistrictId(_ name: String, festival: Festival) -> String {
        let prefix = festival.id.split(separator: "_").first ?? ""
        return "\(prefix)_\(name)"
    }

    private func applyVisibilityToLatestYearRoutes(
        districtId: District.ID,
        festivalId: Festival.ID,
        visibility: Visibility,
        nowYear: Int
    ) async throws {
        let (routes, _) = try await LatestPeriodRouteResolver.fetchLatestRoutes(
            districtId: districtId,
            festivalId: festivalId,
            nowYear: nowYear,
            periodRepository: periodRepository,
            routeRepository: routeRepository
        )
        let routeRepository = routeRepository
        try await withThrowingTaskGroup(of: Void.self) { group in
            for route in routes {
                group.addTask {
                    var updated = route
                    updated.visibility = visibility
                    _ = try await routeRepository.put(updated)
                }
            }
            try await group.waitForAll()
        }
    }
}
