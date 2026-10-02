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
    @Dependency(FestivalPackRepositoryKey.self) var packRepository
    
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

        return try await packRepository.put(pack)
    }
}
