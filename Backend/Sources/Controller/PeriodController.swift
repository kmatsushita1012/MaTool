//
//  PeriodController.swift
//  matool-backend
//
//  Created by 松下和也 on 2025/12/07.
//

import Dependencies
import Shared

enum PeriodControllerKey: DependencyKey {
    static let liveValue: PeriodControllerProtocol = PeriodController()
}

protocol PeriodControllerProtocol: Sendable {
    func get(request: Request, next: Handler) async throws -> Response
    func query(request: Request, next: Handler) async throws -> Response
    func post(request: Request, next: Handler) async throws -> Response
    func put(request: Request, next: Handler) async throws -> Response
    func delete(request: Request, next: Handler) async throws -> Response
}

struct PeriodController: PeriodControllerProtocol {
    @Dependency(PeriodUsecaseKey.self) var usecase
    
    func get(request: Request, next: @Sendable (Application.Request) async throws -> Application.Response) async throws -> Response {
        let festivalId = try request.parameter("periodId", as: String.self)
        let result = try await usecase.get(id: festivalId)
        return try .success(result)
    }
    
    func query(request: Request, next: @Sendable (Application.Request) async throws -> Application.Response) async throws -> Response {
        let festivalId = try request.parameter("festivalId", as: Festival.ID.self)
        let result: [Period]
        if let year = try? request.parameter("year", as: Int.self){
            result = try await usecase.query(by: festivalId, year: year)
        } else {
            result = try await usecase.query(by: festivalId)
        }
        return try .success(result)
    }
    
    func post(request: Request, next: @Sendable (Application.Request) async throws -> Application.Response) async throws -> Response {
        let festivalId = try request.parameter("festivalId", as: Festival.ID.self)
        let user = request.user ?? .guest
        let period = try request.body(as: Period.self)
        let result = try await usecase.post(festivalId: festivalId, period: period, user: user)
        return try .success(result)
    }
    
    func put(request: Request, next: @Sendable (Application.Request) async throws -> Application.Response) async throws -> Response {
        let festivalId = try request.parameter("festivalId", as: Festival.ID.self)
        let year = try request.parameter("year", as: Int.self)
        let user = request.user ?? .guest
        let period = try request.body(as: Period.self)
        let result = try await usecase.put(festivalId: festivalId, period: period, user: user)
        return try .success(result)
    }
    
    func delete(request: Request, next: @Sendable (Application.Request) async throws -> Application.Response) async throws -> Response {
        let id = try request.parameter("periodId", as: Period.ID.self)
        let user = request.user ?? .guest
        let _ = try await usecase.delete(id: id, user: user)
        return try .success()
    }
}
