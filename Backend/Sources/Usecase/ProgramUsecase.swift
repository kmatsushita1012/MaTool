//
//  ProgramUsecase.swift
//  matool-backend
//
//  Created by 松下和也 on 2025/12/07.
//

import Dependencies
import Shared

// MARK: - Dependencies
enum ProgramUsecaseKey: DependencyKey {
    static let liveValue: ProgramUsecaseProtocol = ProgramUsecase()
}

protocol ProgramUsecaseProtocol: Sendable {
    func get(festivalId: String) async throws -> Program
    func get(festivalId: String, year: Int) async throws -> Program
    func query(festivalId: String) async throws -> [Program]
    func post(festivalId: String, program: Program, user: UserRole) async throws -> Program
    func put(festivalId: String, year: Int, program: Program, user: UserRole) async throws -> Program
    func delete(festivalId: String, year: Int, user: UserRole) async throws
}

struct ProgramUsecase: ProgramUsecaseProtocol {
    @Dependency(ProgramRepositoryKey.self) var repository
    
    func get(festivalId: String) async throws -> Program {
        guard let program = try await repository.get(festivalId) else {
            throw Error.notFound("最新の日程が取得できませんでした。")
        }
        return program
    }
    
    func get(festivalId: String, year: Int) async throws -> Program {
        guard year > 0 else {
            throw Error.badRequest("年が正しくありません。")
        }
        guard let program = try await repository.get(festivalId: festivalId, year: year) else {
            throw Error.notFound("指定された日程が取得できませんでした。")
        }
        return program
    }
    
    func query(festivalId: String) async throws -> [Program] {
        return try await repository.query(by: festivalId)
    }
    
    func post(festivalId: String, program: Program, user: UserRole) async throws -> Program {
        guard case let .headquarter(id) = user,
                festivalId == id && program.festivalId == id else {
            throw Error.unauthorized("アクセス権限がありません。")
        }
        guard program.year > 0 else {
            throw Error.badRequest("年が正しくありません。")
        }
        return try await repository.post(program)
    }
    
    func put(festivalId: String, year: Int, program: Program, user: UserRole) async throws -> Program {
        guard case let .headquarter(id) = user,
                festivalId == id && program.festivalId == id else {
            throw Error.unauthorized("アクセス権限がありません。")
        }
        guard program.year > 0 && year > 0 else {
            throw Error.badRequest("年が正しくありません。")
        }
        return try await repository.put(program)
    }
    
    func delete(festivalId: String, year: Int, user: UserRole) async throws {
        guard case let .headquarter(id) = user,
                festivalId == id else {
            throw Error.unauthorized("アクセス権限がありません。")
        }
        return try await repository.delete(festivalId: festivalId, year: year)
    }
}
