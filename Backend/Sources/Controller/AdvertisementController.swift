import Dependencies
import Shared

enum AdvertisementControllerKey: DependencyKey {
    static let liveValue: any AdvertisementControllerProtocol = AdvertisementController()
}

protocol AdvertisementControllerProtocol: Sendable {
    func next(_ request: Request, next: Handler) async throws -> Response
    func impression(_ request: Request, next: Handler) async throws -> Response
    func report(_ request: Request, next: Handler) async throws -> Response
}

struct AdvertisementController: AdvertisementControllerProtocol {
    @Dependency(AdvertisementUsecaseKey.self) var usecase
    @Dependency(ImpressionUsecaseKey.self) var impressionUsecase

    func next(_ request: Request, next: Handler) async throws -> Response {
        let festivalId = try request.parameter("festivalId", as: String.self)
        guard let value = request.parameters["placement"], let placement = StoreAdPlacement(rawValue: value) else {
            throw Error.badRequest("placement は banner または interstitial を指定してください。")
        }
        return try .success(await usecase.next(festivalId: festivalId, placement: placement))
    }

    func impression(_ request: Request, next: Handler) async throws -> Response {
        try await impressionUsecase.report(request.body(as: ImpressionReportRequest.self))
        return try .success()
    }

    func report(_ request: Request, next: Handler) async throws -> Response {
        try await usecase.report(request.body(as: AdvertisementReportRequest.self))
        return try .success()
    }
}
