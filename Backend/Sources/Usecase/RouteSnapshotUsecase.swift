import Dependencies
import Foundation
import Shared

enum RouteSnapshotUsecaseKey: DependencyKey {
    static let liveValue: RouteSnapshotUsecaseProtocol = RouteSnapshotUsecase()
}

extension DependencyValues {
    var routeSnapshotUsecase: RouteSnapshotUsecaseProtocol {
        get { self[RouteSnapshotUsecaseKey.self] }
        set { self[RouteSnapshotUsecaseKey.self] = newValue }
    }
}

struct RouteSnapshotPayload: Equatable, Sendable {
    let contentType: String
    let base64Body: String
}

protocol RouteSnapshotUsecaseProtocol: Sendable {
    func get(routeId: String) async throws -> RouteSnapshotPayload
    func post(routePack: RoutePack) async throws -> RouteSnapshotPayload
}

struct RouteSnapshotUsecase: RouteSnapshotUsecaseProtocol {
    @Dependency(RouteRepositoryKey.self) var routeRepository

    func get(routeId: String) async throws -> RouteSnapshotPayload {
        guard let _ = try await routeRepository.get(id: routeId) else {
            throw Error.notFound("指定されたルートが見つかりません")
        }
        return .init(contentType: "image/png", base64Body: Self.placeholderPngBase64)
    }

    func post(routePack: RoutePack) async throws -> RouteSnapshotPayload {
        _ = routePack
        return .init(contentType: "image/png", base64Body: Self.placeholderPngBase64)
    }
}

private extension RouteSnapshotUsecase {
    static let placeholderPngBase64 = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO7Z0XcAAAAASUVORK5CYII="
}
