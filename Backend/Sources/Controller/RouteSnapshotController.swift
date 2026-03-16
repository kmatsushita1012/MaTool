//
//  RouteSnapshotController.swift
//  matool-backend
//
//  Created by Codex on 2026/03/17.
//

import Dependencies
import Shared

// MARK: - Dependencies
enum RouteSnapshotControllerKey: DependencyKey {
    static let liveValue: any RouteSnapshotControllerProtocol = RouteSnapshotController()
}

// MARK: - RouteSnapshotControllerProtocol
protocol RouteSnapshotControllerProtocol: Sendable {
    func get(_ request: Request, next: Handler) async throws -> Response
    func post(_ request: Request, next: Handler) async throws -> Response
}

// MARK: - RouteSnapshotController
struct RouteSnapshotController: RouteSnapshotControllerProtocol {
    @Dependency(RouteSnapshotUsecaseKey.self) var usecase

    func get(_ request: Request, next: Handler) async throws -> Response {
        let routeId = try request.parameter("routeId", as: String.self)
        print("route snapshot requested: \(routeId)")
        let payload = try await usecase.get(routeId: routeId)
        return .binary(base64: payload.base64Body, contentType: payload.contentType)
    }

    func post(_ request: Request, next: Handler) async throws -> Response {
        let routePack = try request.body(as: RoutePack.self)
        print("route snapshot requested by route pack: \(routePack.route.id)")
        let payload = try await usecase.post(routePack: routePack)
        return .binary(base64: payload.base64Body, contentType: payload.contentType)
    }
}
