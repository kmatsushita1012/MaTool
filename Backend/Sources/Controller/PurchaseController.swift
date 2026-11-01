import Dependencies
import Shared

enum PurchaseControllerKey: DependencyKey {
    static let liveValue: any PurchaseControllerProtocol = PurchaseController()
}

protocol PurchaseControllerProtocol: Sendable {
    func credits(_ request: Request, next: Handler) async throws -> Response
    func history(_ request: Request, next: Handler) async throws -> Response
    func claim(_ request: Request, next: Handler) async throws -> Response
    func notification(_ request: Request, next: Handler) async throws -> Response
}

struct PurchaseController: PurchaseControllerProtocol {
    @Dependency(PurchaseUsecaseKey.self) var usecase

    func credits(_ request: Request, next: Handler) async throws -> Response {
        let storeId = try request.parameter("storeId", as: String.self)
        return try .success(await usecase.credits(storeId: storeId, user: request.user ?? .guest))
    }

    func history(_ request: Request, next: Handler) async throws -> Response {
        let storeId = try request.parameter("storeId", as: String.self)
        return try .success(await usecase.history(storeId: storeId, user: request.user ?? .guest))
    }

    func claim(_ request: Request, next: Handler) async throws -> Response {
        let storeId = try request.parameter("storeId", as: String.self)
        let body = try request.body(as: PurchaseClaimRequest.self)
        return try .success(await usecase.claim(storeId: storeId, signedTransactionInfo: body.signedTransactionInfo, user: request.user ?? .guest))
    }

    func notification(_ request: Request, next: Handler) async throws -> Response {
        let body = try request.body(as: AppStoreNotificationRequest.self)
        try await usecase.applyNotification(signedPayload: body.signedPayload)
        return try .success()
    }
}
