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
protocol DistrictUsecaseProtocol: Usecase {
    func query(by regionId: String) async throws -> [District]
    func get(_ id: String) async throws -> District
    func post(user: UserRole, headquarterId: String, newDistrictName: String, email: String) async throws -> District
    func put(id: String, item: District, user: UserRole) async throws -> District
    func getTools(id: String, user: UserRole) async throws -> DistrictTool
}

// MARK: - DistrictUsecase
struct DistrictUsecase: DistrictUsecaseProtocol {
    @Dependency(DistrictRepositoryKey.self) var repository
    @Dependency(FestivalRepositoryKey.self) var festivalRepository
    @Dependency(AuthManagerFactoryKey.self) var managerFactory
    
    func query(by regionId: String) async throws -> [District] {
        let items = try await repository.query(by: regionId)
        return items
    }
    
    func get(_ id: String) async throws -> District {
        let item = try await repository.get(id: id)
        guard let item else { throw APIError.notFound() }
        return item
    }
    
    func post(user: UserRole, headquarterId: String, newDistrictName: String, email: String) async throws -> District {
        // 認可チェック
        guard case let .headquarter(id) = user, headquarterId == id  else {
            throw APIError.unauthorized()
        }

        // 所属する祭典の取得
        guard let festival = try await festivalRepository.get(id: id) else {
            throw APIError.notFound("所属する祭典が見つかりません")
        }

        // ID生成 & 重複確認
        let districtId = makeDistrictId(name: newDistrictName, region: festival)
        if let _ = try await repository.get(id: districtId) {
            throw APIError.conflict("この名前はすでに登録されています")
        }

        // 招待処理
        let _ = try await managerFactory().create(
            username: districtId,
            email: email
        )

        // District生成
        let district = District(
            id: districtId,
            name: newDistrictName,
            festivalId: headquarterId,
            description: nil,
            base: nil,
            area: [],
            imagePath: nil,
            performances: [],
            visibility: .all
        )

        try await repository.post(item: district)

        return district
    }
    
    func put(id: String, item: District, user: UserRole) async throws -> District {
        guard case let .district(districtId) = user, id == districtId else {
            throw APIError.unauthorized(message: "アクセス権限がありません")
        }
        try await repository.put(id: item.id, item: item)
        return item
    }
    
    func getTools(id: String, user: UserRole) async throws -> DistrictTool {
        // District取得
        guard case let .district(districtId) = user, id == districtId else { throw APIError.unauthorized(message: "アクセス権限がありません") }
        guard let district = try await repository.get(id: id) else {
            throw APIError.notFound("指定された地区が見つかりません")
        }
        guard let festival = try await festivalRepository.get(id: district.festivalId) else {
            throw APIError.notFound("指定された祭典が見つかりません")
        }

        // performances → Information にマッピング
        let performances: [Information] = district.performances.map { performance in
            Information(
                id: performance.id,
                name: performance.name,
                description: "演者 \(performance.performer) \(performance.description ?? "")"
            )
        }

        // DistrictTool を生成
        let item = DistrictTool(
            districtId: district.id,
            districtName: district.name,
            festivalId: festival.id,
            festivalName: festival.name,
            milestones: festival.milestones + performances,
            base: district.base ?? festival.base,
            spans: festival.spans
        )

        return item
    }
}

extension DistrictUsecase {
    func makeDistrictId(name: String, region: Festival) -> String {
        "\(region.id)_\(name)"
    }
}
