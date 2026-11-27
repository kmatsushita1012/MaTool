import Dependencies
import Shared

enum EditionControllerKey: DependencyKey {
    static let liveValue: EditionControllerProtocol = EditionController()
}

protocol EditionControllerProtocol: Sendable {
    func query(request: Request, next: Handler) async throws -> Response
    func create(request: Request, next: Handler) async throws -> Response
    func get(request: Request, next: Handler) async throws -> Response
    func put(request: Request, next: Handler) async throws -> Response
    func putActive(request: Request, next: Handler) async throws -> Response
}

struct EditionController: EditionControllerProtocol {
    @Dependency(EditionUsecaseKey.self) var usecase

    func query(request: Request, next: Handler) async throws -> Response {
        let festivalId = try request.parameter("festivalId", as: Festival.ID.self)
        let result = try await usecase.query(festivalId: festivalId, user: request.user ?? .guest)
        return try .success(result)
    }

    func create(request: Request, next: Handler) async throws -> Response {
        let festivalId = try request.parameter("festivalId", as: Festival.ID.self)
        let form = try request.body(as: EditionCreateForm.self)
        let result = try await usecase.create(festivalId: festivalId, year: form.year, user: request.user ?? .guest)
        return try .success(result)
    }

    func get(request: Request, next: Handler) async throws -> Response {
        let festivalId = try request.parameter("festivalId", as: Festival.ID.self)
        let year = try request.parameter("year", as: Int.self)
        let result = try await usecase.get(festivalId: festivalId, year: year, user: request.user ?? .guest)
        return try .success(result)
    }

    func put(request: Request, next: Handler) async throws -> Response {
        let festivalId = try request.parameter("festivalId", as: Festival.ID.self)
        let year = try request.parameter("year", as: Int.self)
        let pack = try request.body(as: EditionPack.self)
        let result = try await usecase.put(festivalId: festivalId, year: year, pack: pack, user: request.user ?? .guest)
        return try .success(result)
    }

    func putActive(request: Request, next: Handler) async throws -> Response {
        let festivalId = try request.parameter("festivalId", as: Festival.ID.self)
        let form = try request.body(as: ActiveEditionUpdateForm.self)
        let result = try await usecase.putActive(festivalId: festivalId, editionId: form.editionId, user: request.user ?? .guest)
        return try .success(result)
    }
}
