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
    static let liveValue = FestivalUsecase()
}

// MARK: - FestivalUsecaseProtocol
protocol FestivalUsecaseProtocol: Sendable {
    func scan() async throws -> [Festival]
    func get(_ id: String) async throws -> Festival
    func post(_ festival: Festival, user: UserRole) async throws -> Festival
}

// MARK: - FestivalUsecase
struct FestivalUsecase: FestivalUsecaseProtocol {
    @Dependency(FestivalRepositoryKey.self) var repository
    
    func scan() async throws -> [Festival] {
        try await repository.scan()
    }
    
    func get(_ id: String) async throws -> Festival {
        guard let result = try await repository.get(id: id) else {
            throw Error.notFound("存在しない項目です。")
        }
        return result
    }
    
    func post(_ item: Festival, user: UserRole) async throws -> Festival {
        guard case let .headquarter(headquarterId) = user,
              headquarterId == item.id else {
            throw Error.unauthorized("アクセス権限がありません。")
        }
        let result = try await repository.put(item)
        return result
    }
    
    
}
