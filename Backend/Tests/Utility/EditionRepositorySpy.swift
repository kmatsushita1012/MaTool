import Shared
@testable import Backend

final class EditionRepositorySpy: EditionRepositoryProtocol, @unchecked Sendable {
    init(
        getHandler: @escaping (Edition.ID) async throws -> Edition? = { _ in nil },
        getByYearHandler: @escaping (Festival.ID, Int) async throws -> Edition? = { _, _ in nil },
        queryHandler: @escaping (Festival.ID) async throws -> [Edition] = { _ in [] },
        postHandler: @escaping (Edition) async throws -> Edition = { $0 }
    ) {
        self.getHandler = getHandler
        self.getByYearHandler = getByYearHandler
        self.queryHandler = queryHandler
        self.postHandler = postHandler
    }

    private(set) var getCallCount = 0
    private let getHandler: (Edition.ID) async throws -> Edition?
    private(set) var getByYearCallCount = 0
    private let getByYearHandler: (Festival.ID, Int) async throws -> Edition?
    private(set) var queryCallCount = 0
    private let queryHandler: (Festival.ID) async throws -> [Edition]
    private(set) var postCallCount = 0
    private let postHandler: (Edition) async throws -> Edition

    func get(id: Edition.ID) async throws -> Edition? {
        getCallCount += 1
        return try await getHandler(id)
    }

    func get(festivalId: Festival.ID, year: Int) async throws -> Edition? {
        getByYearCallCount += 1
        return try await getByYearHandler(festivalId, year)
    }

    func query(by festivalId: Festival.ID) async throws -> [Edition] {
        queryCallCount += 1
        return try await queryHandler(festivalId)
    }

    func post(_ edition: Edition) async throws -> Edition {
        postCallCount += 1
        return try await postHandler(edition)
    }
}
