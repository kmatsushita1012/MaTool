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
        
        async let oldCheckpointsTask = checkpointRepository.query(by: pack.festival.id)
        async let oldHazardSectionsTask = hazardSectionRepository.query(by: pack.festival.id)
        let (oldCheckpoints, oldHazardSections) = try await (oldCheckpointsTask, oldHazardSectionsTask)

        async let checkpointsTask = oldCheckpoints.update(with: pack.checkpoints, repository: checkpointRepository)
        async let hazardSectionsTask = oldHazardSections.update(with: pack.hazardSections, repository: hazardSectionRepository)
        let (checkpoints, hazardSections) = try await (checkpointsTask, hazardSectionsTask)
        
        return .init(festival: festival, checkpoints: checkpoints, hazardSections: hazardSections)
    }
}
