//
//  FestivalController.swift
//  matool-backend
//
//  Created by 松下和也 on 2025/11/23.
//

import Dependencies
import Shared

// MARK: - Dependencies
enum FestivalControllerKey: DependencyKey {
    static let liveValue: any FestivalControllerProtocol = FestivalController()
}


// MARK: - FestivalControllerProtocol
protocol FestivalControllerProtocol: Sendable {
    func get(_ request: Request, next: Handler) async throws -> Response
    func scan(_ request: Request, next: Handler) async throws -> Response
    func put(_ request: Request, next: Handler) async throws -> Response
}

// MARK: - FestivalController
struct FestivalController: FestivalControllerProtocol {

    @Dependency(FestivalUsecaseKey.self) var usecase

    func get(_ request: Request, next: Handler) async throws -> Response {
        let id = try request.parameter("festivalId", as: String.self)
        let result = try await usecase.get(id)
        return try .success(result)
    }

    public func scan(_ request: Request, next: Handler) async throws -> Response {
        let result = try await usecase.scan()
        return try .success(result)
    }

    public func put(_ request: Request, next: Handler) async throws -> Response {
        let body = try request.body(as: FestivalPack.self)
        let user = request.user ?? .guest
        let result = try await usecase.put(body, user: user)
        return try .success(result)
    }
}
