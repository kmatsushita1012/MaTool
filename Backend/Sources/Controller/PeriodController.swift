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
    func get(_ request: Request, next: Handler) async throws -> Response
    func query(_ request: Request, next: Handler) async throws -> Response
    func post(_ request: Request, next: Handler) async throws -> Response
    func put(_ request: Request, next: Handler) async throws -> Response
    func delete(_ request: Request, next: Handler) async throws -> Response
}

struct PeriodController: PeriodControllerProtocol {
    @Dependency(PeriodUsecaseKey.self) var usecase

    // GET /periods/:id
    func get(_ request: Request, next: Handler) async throws -> Response {
        let id = try request.parameter("id", as: String.self)
        let result = try await usecase.get(id: id)
        return try .success(result)
    }

    // GET /periods?festivalId=...&year=...&all=true
    func query(_ request: Request, next: Handler) async throws -> Response {
        let festivalId = try request.parameter("festivalId", as: String.self)
        let year = try? request.parameter("year", as: Int.self)
        let all = (try? request.parameter("all", as: Bool.self)) ?? false

        let periods: [Period]

        if let year {
            periods = try await usecase.query(festivalId: festivalId, year: year)
        } else if all {
            periods = try await usecase.query(by: festivalId)
        } else {
            periods = try await usecase.queryLatest(by: festivalId)
        }

        return try .success(periods)
    }

    // POST /periods
    func post(_ request: Request, next: Handler) async throws -> Response {
        let user = request.user ?? .guest
        let period = try request.body(as: Period.self)
        let result = try await usecase.post(period: period, user: user)
        return try .success(result)
    }

    // PUT /periods/:id
    func put(_ request: Request, next: Handler) async throws -> Response {
        let id = try request.parameter("id", as: String.self)
        let user = request.user ?? .guest
        let period = try request.body(as: Period.self)
        let result = try await usecase.put(id: id, period: period, user: user)
        return try .success(result)
    }

    // DELETE /periods/:id
    func delete(_ request: Request, next: Handler) async throws -> Response {
        let id = try request.parameter("id", as: String.self)
        let user = request.user ?? .guest
        try await usecase.delete(id: id, user: user)
        return try .success()
    }
}
