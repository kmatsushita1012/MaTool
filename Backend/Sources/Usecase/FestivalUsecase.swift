//
//  FestivalUsecase.swift
//  matool-backend
//
//  Created by 松下和也 on 2025/11/23.
//

import Dependencies
import Shared

// MARK: - Depencies
enum FestivalUsecaseKey: DependencyKey {
    static let liveValue: FestivalUsecaseProtocol = FestivalUsecase()
}

// MARK: - FestivalUsecaseProtocol
protocol FestivalUsecaseProtocol: Sendable {
    func scan() async throws -> [Festival]
    func get(_ id: String) async throws -> FestivalPack
    func put(_ pack: FestivalPack, user: UserRole) async throws -> FestivalPack
}

// MARK: - FestivalUsecase
struct FestivalUsecase: FestivalUsecaseProtocol {
    @Dependency(FestivalRepositoryKey.self) var repository
    @Dependency(CheckpointRepositoryKey.self) var checkpointRepository
    @Dependency(HazardSectionRepositoryKey.self) var hazardSectionRepository
    
    func scan() async throws -> [Festival] {
        try await repository.scan()
    }
    
    func get(_ id: String) async throws -> FestivalPack {
        async let festivalTask = repository.get(id: id)
        async let checkpointsTask = checkpointRepository.query(by: id)
        async let hazardSectionsTask = hazardSectionRepository.query(by: id)
        
        let ( festival, checkpoints, hazardSections ) = (
            try await festivalTask,
            try await checkpointsTask,
            try await hazardSectionsTask
        )
        
        guard let festival else { throw Error.notFound("指定された祭典が見つかりません。") }
        
        return .init(festival: festival, checkpoints: checkpoints, hazardSections: hazardSections)
    }
    
    func put(_ pack: FestivalPack, user: UserRole) async throws -> FestivalPack {
        guard case let .headquarter(headquarterId) = user,
              headquarterId == pack.festival.id else {
            throw Error.unauthorized("アクセス権限がありません。")
        }
        
        let festival = try await repository.put(pack.festival)
        
        let oldCheckpoints = try await checkpointRepository.query(by: pack.festival.id)
        let checkpoints = try await oldCheckpoints.update(with: pack.checkpoints, repository: checkpointRepository)
        
        let oldHazardSection = try await hazardSectionRepository.query(by: pack.festival.id)
        let hazardSections = try await oldHazardSection.update(with: pack.hazardSections, repository: hazardSectionRepository)
        
        return .init(festival: festival, checkpoints: checkpoints, hazardSections: hazardSections)
    }
}
