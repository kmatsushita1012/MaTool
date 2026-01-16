import Foundation
import Dependencies
import Shared

enum SceneControllerKey: DependencyKey {
    static let liveValue: SceneControlelrProtocol = SceneController()
}

protocol SceneControlelrProtocol: Sendable {
    func launchFestival(_ request: Request, next: Handler) async throws -> Response
    func launchDistrict(_ request: Request, next: Handler) async throws -> Response
    func login(_ request: Request, next: Handler) async throws -> Response
}

struct SceneController: SceneControlelrProtocol {
    @Dependency(SceneUsecaseKey.self) var sceneUsecase

    func launchFestival(_ request: Request, next: Handler) async throws -> Response {
        let festivalId = try request.parameter("festivalId", as: String.self)
        let user = request.user ?? .guest
        let pack = try await sceneUsecase.fetchLaunchFestivalPack(festivalId: festivalId, user: user)
        return try .success(pack)
    }

    func launchDistrict(_ request: Request, next: Handler) async throws -> Response {
        let districtId = try request.parameter("districtId", as: String.self)
        let user = request.user ?? .guest
        let pack = try await sceneUsecase.fetchLaunchDistrictPack(districtId: districtId, user: user)
        return try .success(pack)
    }

    func login(_ request: Request, next: Handler) async throws -> Response {
        let user = request.user ?? .guest
        let pack = try await sceneUsecase.fetchLoginPack(user: user)
        return try .success(pack)
    }
}
