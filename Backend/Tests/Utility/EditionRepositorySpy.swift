import Shared
@testable import Backend

final class EditionRepositorySpy: EditionRepositoryProtocol, @unchecked Sendable {
    init(getHandler: @escaping (Edition.ID) async throws -> Edition? = { _ in nil }) {
        self.getHandler = getHandler
    }

    private(set) var getCallCount = 0
    private let getHandler: (Edition.ID) async throws -> Edition?

    func get(id: Edition.ID) async throws -> Edition? {
        getCallCount += 1
        return try await getHandler(id)
    }

    func get(festivalId: Festival.ID, year: Int) async throws -> Edition? {
        throw TestError.unimplemented
    }

    func query(by festivalId: Festival.ID) async throws -> [Edition] {
        throw TestError.unimplemented
    }

    func post(_ edition: Edition) async throws -> Edition {
        throw TestError.unimplemented
    }
}
