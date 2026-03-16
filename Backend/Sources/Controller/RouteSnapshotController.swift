//
//  RouteSnapshotController.swift
//  matool-backend
//
//  Created by Codex on 2026/03/17.
//

import Dependencies

// MARK: - Dependencies
enum RouteSnapshotControllerKey: DependencyKey {
    static let liveValue: any RouteSnapshotControllerProtocol = RouteSnapshotController()
}

// MARK: - RouteSnapshotControllerProtocol
protocol RouteSnapshotControllerProtocol: Sendable {
    func get(_ request: Request, next: Handler) async throws -> Response
}

// MARK: - RouteSnapshotController
struct RouteSnapshotController: RouteSnapshotControllerProtocol {
    func get(_ request: Request, next: Handler) async throws -> Response {
        let routeId = try request.parameter("routeId", as: String.self)
        print("route snapshot requested: \(routeId)")
        return .binary(base64: Self.placeholderPngBase64, contentType: "image/png")
    }
}

private extension RouteSnapshotController {
    // 1x1 blue PNG
    static let placeholderPngBase64 = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADUlEQVR42mNk+M/wHwAE/wJ/l8sRPwAAAABJRU5ErkJggg=="
}
