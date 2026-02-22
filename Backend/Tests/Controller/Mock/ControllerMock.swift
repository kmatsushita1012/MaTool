@testable import Backend

final class FestivalControllerMock: FestivalControllerProtocol, @unchecked Sendable {
    init(
        getHandler: ((Request, Handler) throws -> Response)? = nil,
        scanHandler: ((Request, Handler) throws -> Response)? = nil,
        putHandler: ((Request, Handler) throws -> Response)? = nil
    ) {
        self.getHandler = getHandler
        self.scanHandler = scanHandler
        self.putHandler = putHandler
    }

    private(set) var getCallCount = 0
    private let getHandler: ((Request, Handler) throws -> Response)?
    func get(_ request: Request, next: Handler) async throws -> Response {
        getCallCount += 1
        guard let getHandler else { throw TestError.unimplemented }
        return try getHandler(request, next)
    }

    private(set) var scanCallCount = 0
    private let scanHandler: ((Request, Handler) throws -> Response)?
    func scan(_ request: Request, next: Handler) async throws -> Response {
        scanCallCount += 1
        guard let scanHandler else { throw TestError.unimplemented }
        return try scanHandler(request, next)
    }

    private(set) var putCallCount = 0
    private let putHandler: ((Request, Handler) throws -> Response)?
    func put(_ request: Request, next: Handler) async throws -> Response {
        putCallCount += 1
        guard let putHandler else { throw TestError.unimplemented }
        return try putHandler(request, next)
    }
}

final class DistrictControllerMock: DistrictControllerProtocol, @unchecked Sendable {
    init(
        getHandler: ((Request, Handler) throws -> Response)? = nil,
        queryHandler: ((Request, Handler) throws -> Response)? = nil,
        postHandler: ((Request, Handler) throws -> Response)? = nil,
        putHandler: ((Request, Handler) throws -> Response)? = nil,
        updateDistrictHandler: ((Request, Handler) throws -> Response)? = nil
    ) {
        self.getHandler = getHandler
        self.queryHandler = queryHandler
        self.postHandler = postHandler
        self.putHandler = putHandler
        self.updateDistrictHandler = updateDistrictHandler
    }

    private(set) var getCallCount = 0
    private let getHandler: ((Request, Handler) throws -> Response)?
    func get(_ request: Request, next: Handler) async throws -> Response {
        getCallCount += 1
        guard let getHandler else { throw TestError.unimplemented }
        return try getHandler(request, next)
    }

    private(set) var queryCallCount = 0
    private let queryHandler: ((Request, Handler) throws -> Response)?
    func query(_ request: Request, next: Handler) async throws -> Response {
        queryCallCount += 1
        guard let queryHandler else { throw TestError.unimplemented }
        return try queryHandler(request, next)
    }

    private(set) var postCallCount = 0
    private let postHandler: ((Request, Handler) throws -> Response)?
    func post(_ request: Request, next: Handler) async throws -> Response {
        postCallCount += 1
        guard let postHandler else { throw TestError.unimplemented }
        return try postHandler(request, next)
    }

    private(set) var putCallCount = 0
    private let putHandler: ((Request, Handler) throws -> Response)?
    func put(_ request: Request, next: Handler) async throws -> Response {
        putCallCount += 1
        guard let putHandler else { throw TestError.unimplemented }
        return try putHandler(request, next)
    }

    private(set) var updateDistrictCallCount = 0
    private let updateDistrictHandler: ((Request, Handler) throws -> Response)?
    func updateDistrict(_ request: Request, next: Handler) async throws -> Response {
        updateDistrictCallCount += 1
        guard let updateDistrictHandler else { throw TestError.unimplemented }
        return try updateDistrictHandler(request, next)
    }
}

final class RouteControllerMock: RouteControllerProtocol, @unchecked Sendable {
    init(
        getHandler: ((Request, Handler) throws -> Response)? = nil,
        queryHandler: ((Request, Handler) throws -> Response)? = nil,
        postHandler: ((Request, Handler) throws -> Response)? = nil,
        putHandler: ((Request, Handler) throws -> Response)? = nil,
        deleteHandler: ((Request, Handler) throws -> Response)? = nil
    ) {
        self.getHandler = getHandler
        self.queryHandler = queryHandler
        self.postHandler = postHandler
        self.putHandler = putHandler
        self.deleteHandler = deleteHandler
    }

    private(set) var getCallCount = 0
    private let getHandler: ((Request, Handler) throws -> Response)?
    func get(_ request: Request, next: Handler) async throws -> Response {
        getCallCount += 1
        guard let getHandler else { throw TestError.unimplemented }
        return try getHandler(request, next)
    }

    private(set) var queryCallCount = 0
    private let queryHandler: ((Request, Handler) throws -> Response)?
    func query(_ request: Request, next: Handler) async throws -> Response {
        queryCallCount += 1
        guard let queryHandler else { throw TestError.unimplemented }
        return try queryHandler(request, next)
    }

    private(set) var postCallCount = 0
    private let postHandler: ((Request, Handler) throws -> Response)?
    func post(_ request: Request, next: Handler) async throws -> Response {
        postCallCount += 1
        guard let postHandler else { throw TestError.unimplemented }
        return try postHandler(request, next)
    }

    private(set) var putCallCount = 0
    private let putHandler: ((Request, Handler) throws -> Response)?
    func put(_ request: Request, next: Handler) async throws -> Response {
        putCallCount += 1
        guard let putHandler else { throw TestError.unimplemented }
        return try putHandler(request, next)
    }

    private(set) var deleteCallCount = 0
    private let deleteHandler: ((Request, Handler) throws -> Response)?
    func delete(_ request: Request, next: Handler) async throws -> Response {
        deleteCallCount += 1
        guard let deleteHandler else { throw TestError.unimplemented }
        return try deleteHandler(request, next)
    }
}

final class LocationControllerMock: LocationControllerProtocol, @unchecked Sendable {
    init(
        getHandler: ((Request, Handler) throws -> Response)? = nil,
        queryHandler: ((Request, Handler) throws -> Response)? = nil,
        putHandler: ((Request, Handler) throws -> Response)? = nil,
        deleteHandler: ((Request, Handler) throws -> Response)? = nil
    ) {
        self.getHandler = getHandler
        self.queryHandler = queryHandler
        self.putHandler = putHandler
        self.deleteHandler = deleteHandler
    }

    private(set) var getCallCount = 0
    private let getHandler: ((Request, Handler) throws -> Response)?
    func get(_ request: Request, next: Handler) async throws -> Response {
        getCallCount += 1
        guard let getHandler else { throw TestError.unimplemented }
        return try getHandler(request, next)
    }

    private(set) var queryCallCount = 0
    private let queryHandler: ((Request, Handler) throws -> Response)?
    func query(_ request: Request, next: Handler) async throws -> Response {
        queryCallCount += 1
        guard let queryHandler else { throw TestError.unimplemented }
        return try queryHandler(request, next)
    }

    private(set) var putCallCount = 0
    private let putHandler: ((Request, Handler) throws -> Response)?
    func put(_ request: Request, next: Handler) async throws -> Response {
        putCallCount += 1
        guard let putHandler else { throw TestError.unimplemented }
        return try putHandler(request, next)
    }

    private(set) var deleteCallCount = 0
    private let deleteHandler: ((Request, Handler) throws -> Response)?
    func delete(_ request: Request, next: Handler) async throws -> Response {
        deleteCallCount += 1
        guard let deleteHandler else { throw TestError.unimplemented }
        return try deleteHandler(request, next)
    }
}

final class PeriodControllerMock: PeriodControllerProtocol, @unchecked Sendable {
    init(
        getHandler: ((Request, Handler) throws -> Response)? = nil,
        queryHandler: ((Request, Handler) throws -> Response)? = nil,
        postHandler: ((Request, Handler) throws -> Response)? = nil,
        putHandler: ((Request, Handler) throws -> Response)? = nil,
        deleteHandler: ((Request, Handler) throws -> Response)? = nil
    ) {
        self.getHandler = getHandler
        self.queryHandler = queryHandler
        self.postHandler = postHandler
        self.putHandler = putHandler
        self.deleteHandler = deleteHandler
    }

    private(set) var getCallCount = 0
    private let getHandler: ((Request, Handler) throws -> Response)?
    func get(request: Request, next: Handler) async throws -> Response {
        getCallCount += 1
        guard let getHandler else { throw TestError.unimplemented }
        return try getHandler(request, next)
    }

    private(set) var queryCallCount = 0
    private let queryHandler: ((Request, Handler) throws -> Response)?
    func query(request: Request, next: Handler) async throws -> Response {
        queryCallCount += 1
        guard let queryHandler else { throw TestError.unimplemented }
        return try queryHandler(request, next)
    }

    private(set) var postCallCount = 0
    private let postHandler: ((Request, Handler) throws -> Response)?
    func post(request: Request, next: Handler) async throws -> Response {
        postCallCount += 1
        guard let postHandler else { throw TestError.unimplemented }
        return try postHandler(request, next)
    }

    private(set) var putCallCount = 0
    private let putHandler: ((Request, Handler) throws -> Response)?
    func put(request: Request, next: Handler) async throws -> Response {
        putCallCount += 1
        guard let putHandler else { throw TestError.unimplemented }
        return try putHandler(request, next)
    }

    private(set) var deleteCallCount = 0
    private let deleteHandler: ((Request, Handler) throws -> Response)?
    func delete(request: Request, next: Handler) async throws -> Response {
        deleteCallCount += 1
        guard let deleteHandler else { throw TestError.unimplemented }
        return try deleteHandler(request, next)
    }
}

final class SceneControllerMock: SceneControlelrProtocol, @unchecked Sendable {
    init(
        launchFestivalHandler: ((Request, Handler) throws -> Response)? = nil,
        launchDistrictHandler: ((Request, Handler) throws -> Response)? = nil
    ) {
        self.launchFestivalHandler = launchFestivalHandler
        self.launchDistrictHandler = launchDistrictHandler
    }

    private(set) var launchFestivalCallCount = 0
    private let launchFestivalHandler: ((Request, Handler) throws -> Response)?
    func launchFestival(_ request: Request, next: Handler) async throws -> Response {
        launchFestivalCallCount += 1
        guard let launchFestivalHandler else { throw TestError.unimplemented }
        return try launchFestivalHandler(request, next)
    }

    private(set) var launchDistrictCallCount = 0
    private let launchDistrictHandler: ((Request, Handler) throws -> Response)?
    func launchDistrict(_ request: Request, next: Handler) async throws -> Response {
        launchDistrictCallCount += 1
        guard let launchDistrictHandler else { throw TestError.unimplemented }
        return try launchDistrictHandler(request, next)
    }
}
