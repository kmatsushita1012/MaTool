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
    
    func put(id: String, item: DistrictPack, user: UserRole) async throws -> DistrictPack {
        guard case let .district(districtId) = user, id == districtId else {
            throw Error.unauthorized("アクセス権限がありません")
        }
        let district = try await repository.put(id: id, item: item.district)
        
        let oldPerformances = try await peformanceRepository.query(by: districtId)
        let performances = try await oldPerformances.update(with: item.performances, repository: peformanceRepository)
        
        return .init(district: district, performances: performances)
    }
    
    // HQ権限
    func put(id: String, district: District, user: UserRole) async throws -> District {
        guard case let .headquarter(hqId) = user, district.festivalId == hqId, id == district.id else {
            throw Error.unauthorized("アクセス権限がありません")
        }
        let result = try await repository.put(id: id, item: district)
        
        return result
    }
}

extension DistrictUsecase {
    private func makeDistrictId(_ name: String, festival: Festival) -> String {
        let prefix = festival.id.split(separator: "_").first ?? ""
        return "\(prefix)_\(name)"
    }

}
