import Dependencies
import Shared

enum StoreControllerKey: DependencyKey {
    static let liveValue: any StoreControllerProtocol = StoreController()
}

protocol StoreControllerProtocol: Sendable {
    func owned(_ request: Request, next: Handler) async throws -> Response
    func create(_ request: Request, next: Handler) async throws -> Response
    func get(_ request: Request, next: Handler) async throws -> Response
    func put(_ request: Request, next: Handler) async throws -> Response
    func publicList(_ request: Request, next: Handler) async throws -> Response
}

struct StoreController: StoreControllerProtocol {
    @Dependency(StoreUsecaseKey.self) var usecase

    func owned(_ request: Request, next: Handler) async throws -> Response {
        let result = try await usecase.storesOwned(by: request.user ?? .guest)
        return try .success(result)
    }

    func create(_ request: Request, next: Handler) async throws -> Response {
        let festivalId = try request.parameter("festivalId", as: String.self)
        let body = try request.body(as: StoreCreateRequest.self)
        let result = try await usecase.create(festivalId: festivalId, request: body, user: request.user ?? .guest)
        return try .success(result)
    }

    func get(_ request: Request, next: Handler) async throws -> Response {
        let storeId = try request.parameter("storeId", as: String.self)
        let result = try await usecase.get(id: storeId, user: request.user ?? .guest)
        return try .success(result)
    }

    func put(_ request: Request, next: Handler) async throws -> Response {
        let storeId = try request.parameter("storeId", as: String.self)
        let body = try request.body(as: Store.self)
        let result = try await usecase.put(id: storeId, request: body, user: request.user ?? .guest)
        return try .success(result)
    }

    func publicList(_ request: Request, next: Handler) async throws -> Response {
        let festivalId = try request.parameter("festivalId", as: String.self)
        let result = try await usecase.publicStores(in: festivalId)
        return try .success(result)
    }
}
