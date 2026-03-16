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
    func postDistrict(districtId: String, year: String) async throws -> RouteSnapshotPayload
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

    func postDistrict(districtId: String, year: String) async throws -> RouteSnapshotPayload {
        let routes: [Route]
        if year == "latest" {
            routes = try await routeRepository.query(by: districtId)
        } else {
            guard let year = Int(year) else {
                throw Error.badRequest("year は latest または yyyy を指定してください")
            }
            routes = try await routeRepository.query(by: districtId, year: year)
        }

        guard !routes.isEmpty else {
            throw Error.notFound("指定された条件でルートが見つかりません")
        }
        return .init(contentType: "application/pdf", base64Body: Self.placeholderPdfBase64)
    }
}

private extension RouteSnapshotUsecase {
    static let placeholderPngBase64 = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO7Z0XcAAAAASUVORK5CYII="
    static let placeholderPdfBase64 = "JVBERi0xLjQKJUVPRgo="
}
