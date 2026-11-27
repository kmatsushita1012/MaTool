@testable import Backend

final class EditionControllerSpy: EditionControllerProtocol, @unchecked Sendable {
    private(set) var calls: [String] = []

    func query(request: Request, next: Handler) async throws -> Response { calls.append("query"); return try .success() }
    func create(request: Request, next: Handler) async throws -> Response { calls.append("create"); return try .success() }
    func get(request: Request, next: Handler) async throws -> Response { calls.append("get"); return try .success() }
    func put(request: Request, next: Handler) async throws -> Response { calls.append("put"); return try .success() }
    func putActive(request: Request, next: Handler) async throws -> Response { calls.append("putActive"); return try .success() }
}
