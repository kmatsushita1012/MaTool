//
//  ProgramController.swift
//  matool-backend
//
//  Created by 松下和也 on 2025/12/07.
//

import Dependencies
import Shared

enum ProgramControllerKey: DependencyKey {
    static let liveValue: ProgramControllerProtocol = ProgramController()
}

protocol ProgramControllerProtocol: Sendable {
    func getLatest(request: Request, next: Handler) async throws -> Response
    func get(request: Request, next: Handler) async throws -> Response
    func query(request: Request, next: Handler) async throws -> Response
    func post(request: Request, next: Handler) async throws -> Response
    func put(request: Request, next: Handler) async throws -> Response
    func delete(request: Request, next: Handler) async throws -> Response
}

struct ProgramController: ProgramControllerProtocol {
    @Dependency(ProgramUsecaseKey.self) var usecase
    
    func getLatest(request: Request, next: @Sendable (Application.Request) async throws -> Application.Response) async throws -> Response {
        let festivalId = try request.parameter("festivalId", as: String.self)
        let result = try await usecase.get(festivalId: festivalId)
        return try .success(result)
    }
    
    func get(request: Request, next: @Sendable (Application.Request) async throws -> Application.Response) async throws -> Response {
        let festivalId = try request.parameter("festivalId", as: String.self)
        let year = try request.parameter("year", as: Int.self)
        let result = try await usecase.get(festivalId: festivalId, year: year)
        return try .success(result)
    }
    
    func query(request: Request, next: @Sendable (Application.Request) async throws -> Application.Response) async throws -> Response {
        let festivalId = try request.parameter("festivalId", as: String.self)
        let result = try await usecase.query(festivalId: festivalId)
        return try .success(result)
    }
    
    func post(request: Request, next: @Sendable (Application.Request) async throws -> Application.Response) async throws -> Response {
        let festivalId = try request.parameter("festivalId", as: String.self)
        let user = request.user ?? .guest
        let program = try request.body(as: Program.self)
        let result = try await usecase.post(festivalId: festivalId, program: program, user: user)
        return try .success(result)
    }
    
    func put(request: Request, next: @Sendable (Application.Request) async throws -> Application.Response) async throws -> Response {
        let festivalId = try request.parameter("festivalId", as: String.self)
        let year = try request.parameter("year", as: Int.self)
        let user = request.user ?? .guest
        let program = try request.body(as: Program.self)
        let result = try await usecase.put(festivalId: festivalId, year: year, program: program, user: user)
        return try .success(result)
    }
    
    func delete(request: Request, next: @Sendable (Application.Request) async throws -> Application.Response) async throws -> Response {
        let festivalId = try request.parameter("festivalId", as: String.self)
        let year = try request.parameter("year", as: Int.self)
        let user = request.user ?? .guest
        let _ = try await usecase.delete(festivalId: festivalId, year: year, user: user)
        return try .success()
    }
}
