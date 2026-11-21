import Shared
@testable import Backend

final class EditionUsecaseSpy: EditionUsecaseProtocol, @unchecked Sendable {
    init(
        queryHandler: @escaping (Festival.ID, UserRole) async throws -> EditionListResponse = { _, _ in throw TestError.unimplemented },
        createHandler: @escaping (Festival.ID, Int, UserRole) async throws -> EditionPack = { _, _, _ in throw TestError.unimplemented },
        getHandler: @escaping (Festival.ID, Int, UserRole) async throws -> EditionPack = { _, _, _ in throw TestError.unimplemented },
        putHandler: @escaping (Festival.ID, Int, EditionPack, UserRole) async throws -> EditionPack = { _, _, _, _ in throw TestError.unimplemented },
        putActiveHandler: @escaping (Festival.ID, Edition.ID, UserRole) async throws -> ActiveEdition = { _, _, _ in throw TestError.unimplemented }
    ) {
        self.queryHandler = queryHandler
        self.createHandler = createHandler
        self.getHandler = getHandler
        self.putHandler = putHandler
        self.putActiveHandler = putActiveHandler
    }

    private let queryHandler: (Festival.ID, UserRole) async throws -> EditionListResponse
    private let createHandler: (Festival.ID, Int, UserRole) async throws -> EditionPack
    private let getHandler: (Festival.ID, Int, UserRole) async throws -> EditionPack
    private let putHandler: (Festival.ID, Int, EditionPack, UserRole) async throws -> EditionPack
    private let putActiveHandler: (Festival.ID, Edition.ID, UserRole) async throws -> ActiveEdition
    private(set) var calls: [String] = []

    func query(festivalId: Festival.ID, user: UserRole) async throws -> EditionListResponse {
        calls.append("query")
        return try await queryHandler(festivalId, user)
    }

    func create(festivalId: Festival.ID, year: Int, user: UserRole) async throws -> EditionPack {
        calls.append("create")
        return try await createHandler(festivalId, year, user)
    }

    func get(festivalId: Festival.ID, year: Int, user: UserRole) async throws -> EditionPack {
        calls.append("get")
        return try await getHandler(festivalId, year, user)
    }

    func put(festivalId: Festival.ID, year: Int, pack: EditionPack, user: UserRole) async throws -> EditionPack {
        calls.append("put")
        return try await putHandler(festivalId, year, pack, user)
    }

    func putActive(festivalId: Festival.ID, editionId: Edition.ID, user: UserRole) async throws -> ActiveEdition {
        calls.append("putActive")
        return try await putActiveHandler(festivalId, editionId, user)
    }
}
