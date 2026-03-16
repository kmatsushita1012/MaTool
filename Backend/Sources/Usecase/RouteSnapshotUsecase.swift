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
    @Dependency(PointRepositoryKey.self) var pointRepository
    @Dependency(RouteSnapshotRendererKey.self) var renderer

    func get(routeId: String) async throws -> RouteSnapshotPayload {
        guard let route = try await routeRepository.get(id: routeId) else {
            throw Error.notFound("指定されたルートが見つかりません")
        }
        let points = try await pointRepository.query(by: route.id)
        let data = try renderer.renderPNG(routeId: route.id, points: points)
        return .init(contentType: "image/png", base64Body: data.base64EncodedString())
    }

    func post(routePack: RoutePack) async throws -> RouteSnapshotPayload {
        let data = try renderer.renderPNG(routeId: routePack.route.id, points: routePack.points)
        return .init(contentType: "image/png", base64Body: data.base64EncodedString())
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
        var pages: [RouteSnapshotPageInput] = []
        pages.reserveCapacity(routes.count)
        for route in routes {
            let points = try await pointRepository.query(by: route.id)
            pages.append(.init(routeId: route.id, points: points))
        }
        let data = try renderer.renderPDF(pages: pages)
        return .init(contentType: "application/pdf", base64Body: data.base64EncodedString())
    }
}
