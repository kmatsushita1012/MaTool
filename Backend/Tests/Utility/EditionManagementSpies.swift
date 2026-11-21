import Shared
@testable import Backend

final class ActiveEditionRepositorySpy: ActiveEditionRepositoryProtocol, @unchecked Sendable {
    init(
        getHandler: @escaping (Festival.ID) async throws -> ActiveEdition? = { _ in nil },
        putHandler: @escaping (ActiveEdition) async throws -> ActiveEdition = { $0 }
    ) {
        self.getHandler = getHandler
        self.putHandler = putHandler
    }

    private(set) var getCallCount = 0
    private let getHandler: (Festival.ID) async throws -> ActiveEdition?
    private(set) var putCallCount = 0
    private let putHandler: (ActiveEdition) async throws -> ActiveEdition

    func get(festivalId: Festival.ID) async throws -> ActiveEdition? {
        getCallCount += 1
        return try await getHandler(festivalId)
    }

    func put(_ activeEdition: ActiveEdition) async throws -> ActiveEdition {
        putCallCount += 1
        return try await putHandler(activeEdition)
    }
}

final class PeriodRepositorySpy: PeriodRepositoryProtocol, @unchecked Sendable {
    init(
        getHandler: @escaping (Period.ID) async throws -> Period? = { _ in nil },
        queryByEditionHandler: @escaping (Edition.ID) async throws -> [Period] = { _ in [] },
        putHandler: @escaping (Period) async throws -> Period = { $0 },
        deleteHandler: @escaping (Period.ID) async throws -> Void = { _ in }
    ) {
        self.getHandler = getHandler
        self.queryByEditionHandler = queryByEditionHandler
        self.putHandler = putHandler
        self.deleteHandler = deleteHandler
    }

    private(set) var getCallCount = 0
    private let getHandler: (Period.ID) async throws -> Period?
    private(set) var queryByEditionCallCount = 0
    private let queryByEditionHandler: (Edition.ID) async throws -> [Period]
    private(set) var putCallCount = 0
    private let putHandler: (Period) async throws -> Period
    private(set) var deletedIDs: [Period.ID] = []
    private let deleteHandler: (Period.ID) async throws -> Void

    func get(id: Period.ID) async throws -> Period? {
        getCallCount += 1
        return try await getHandler(id)
    }

    func query(byEditionId editionId: Edition.ID) async throws -> [Period] {
        queryByEditionCallCount += 1
        return try await queryByEditionHandler(editionId)
    }

    func query(by festivalId: Festival.ID, year: Int) async throws -> [Period] { throw TestError.unimplemented }
    func query(by festivalId: Festival.ID) async throws -> [Period] { throw TestError.unimplemented }
    func post(_ period: Period) async throws -> Period { throw TestError.unimplemented }

    func put(_ period: Period) async throws -> Period {
        putCallCount += 1
        return try await putHandler(period)
    }

    func delete(id: Period.ID) async throws {
        deletedIDs.append(id)
        try await deleteHandler(id)
    }
}

final class DistrictManagementRepositorySpy: DistrictRepositoryProtocol, @unchecked Sendable {
    init(queryHandler: @escaping (Festival.ID) async throws -> [District] = { _ in [] }) {
        self.queryHandler = queryHandler
    }

    private let queryHandler: (Festival.ID) async throws -> [District]
    func get(id: String) async throws -> District? { throw TestError.unimplemented }
    func query(by festivalId: String) async throws -> [District] { try await queryHandler(festivalId) }
    func put(id: String, item: District) async throws -> District { throw TestError.unimplemented }
    func post(item: District) async throws -> District { throw TestError.unimplemented }
}

final class RouteManagementRepositorySpy: RouteRepositoryProtocol, @unchecked Sendable {
    init(
        queryHandler: @escaping (District.ID) async throws -> [Route] = { _ in [] },
        deleteHandler: @escaping (Route) async throws -> Void = { _ in }
    ) {
        self.queryHandler = queryHandler
        self.deleteHandler = deleteHandler
    }

    private let queryHandler: (District.ID) async throws -> [Route]
    private let deleteHandler: (Route) async throws -> Void
    private(set) var deletedIDs: [Route.ID] = []

    func get(id: String) async throws -> Route? { throw TestError.unimplemented }
    func query(by districtId: String) async throws -> [Route] { try await queryHandler(districtId) }
    func query(by districtId: String, editionId: Edition.ID) async throws -> [Route] { throw TestError.unimplemented }
    func query(by districtId: String, year: Int) async throws -> [Route] { throw TestError.unimplemented }
    func post(_ route: Route) async throws -> Route { throw TestError.unimplemented }
    func put(_ route: Route) async throws -> Route { throw TestError.unimplemented }
    func delete(id: String) async throws { throw TestError.unimplemented }

    func delete(_ route: Route) async throws {
        deletedIDs.append(route.id)
        try await deleteHandler(route)
    }
}

final class PointManagementRepositorySpy: PointRepositoryProtocol, @unchecked Sendable {
    init(deleteHandler: @escaping (Route.ID) async throws -> Void = { _ in }) {
        self.deleteHandler = deleteHandler
    }

    private let deleteHandler: (Route.ID) async throws -> Void
    private(set) var deletedRouteIDs: [Route.ID] = []
    func get(id: Point.ID) async throws -> Point? { throw TestError.unimplemented }
    func query(by routeId: String) async throws -> [Point] { throw TestError.unimplemented }
    func put(_ item: Point) async throws -> Point { throw TestError.unimplemented }
    func post(_ item: Point) async throws -> Point { throw TestError.unimplemented }
    func delete(_ item: Point) async throws { throw TestError.unimplemented }
    func delete(by routeId: Route.ID) async throws {
        deletedRouteIDs.append(routeId)
        try await deleteHandler(routeId)
    }
}

final class PassageManagementRepositorySpy: PassageRepositoryProtocol, @unchecked Sendable {
    init(deleteHandler: @escaping (Route.ID) async throws -> Void = { _ in }) {
        self.deleteHandler = deleteHandler
    }

    private let deleteHandler: (Route.ID) async throws -> Void
    private(set) var deletedRouteIDs: [Route.ID] = []
    func get(id: RoutePassage.ID) async throws -> RoutePassage? { throw TestError.unimplemented }
    func query(by routeId: String) async throws -> [RoutePassage] { throw TestError.unimplemented }
    func put(_ item: RoutePassage) async throws -> RoutePassage { throw TestError.unimplemented }
    func post(_ item: RoutePassage) async throws -> RoutePassage { throw TestError.unimplemented }
    func delete(_ item: RoutePassage) async throws { throw TestError.unimplemented }
    func delete(by routeId: Route.ID) async throws {
        deletedRouteIDs.append(routeId)
        try await deleteHandler(routeId)
    }
}
