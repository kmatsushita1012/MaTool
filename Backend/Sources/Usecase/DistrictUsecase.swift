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
        guard let item else { throw Error.notFound("指定された地区が見つかりません") }
        return item
    }
    
    func post(user: UserRole, headquarterId: String, newDistrictName: String, email: String) async throws -> District {
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

        return try await repository.post(item: district)
    }
    
    func put(id: String, item: District, user: UserRole) async throws -> District {
        guard case let .district(districtId) = user, id == districtId else {
            throw Error.unauthorized("アクセス権限がありません")
        }
        return try await repository.put(id: item.id, item: item)
    }
    
    func getTools(id: String, user: UserRole) async throws -> DistrictTool {
        // District取得
        guard case let .district(districtId) = user, id == districtId else {
            throw Error.unauthorized("アクセス権限がありません")
        }
        guard let district = try await repository.get(id: id) else {
            throw Error.notFound("指定された地区が見つかりません")
        }
        guard let festival = try await festivalRepository.get(id: district.festivalId) else {
            throw Error.notFound("指定された祭典が見つかりません")
        }

        // performances → Checkpoint にマッピング
        let performances: [Checkpoint] = district.performances.map { performance in
            Checkpoint(
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
            checkpoints: festival.checkpoints + performances,
            base: district.base ?? festival.base,
            periods: festival.periods,
            hazardSections: festival.hazardSections
        )

        return item
    }
}

extension DistrictUsecase {
    private func makeDistrictId(_ name: String, festival: Festival) -> String {
        let prefix = festival.id.split(separator: "_").first ?? ""
        return "\(prefix)_\(name)"
    }

}
