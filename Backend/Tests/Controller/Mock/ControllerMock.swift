//
//  ControllerMock.swift
//  matool-backend
//
//  Created by 松下和也 on 2025/11/24.
//

@testable import Backend

final class FestivalControllerMock: FestivalControllerProtocol, @unchecked Sendable {
    
    init(
        getHandler: ((Request, Handler) throws -> Response)? = nil,
        scanHandler: ((Request, Handler) throws -> Response)? = nil
        , putHandler: ((Request, Handler) throws -> Response)? = nil
    ) {
        self.getHandler = getHandler
        self.scanHandler = scanHandler
        self.putHandler = putHandler
    }
    
    var getCallCount: Int = 0
    var getHandler: ((Request, Handler) throws -> Response)?
    func get(_ request: Request, next: Handler) async throws -> Backend.Response {
        getCallCount+=1
        guard let getHandler else { throw TestError.unimplemented }
        return try getHandler(request, next)
    }
    
    var scanCallCount: Int = 0
    var scanHandler: ((Request, Handler) throws -> Response)?
    func scan(_ request: Backend.Request, next: @Sendable (Backend.Application.Request) async throws -> Backend.Application.Response) async throws -> Backend.Response {
        scanCallCount+=1
        guard let scanHandler else { throw TestError.unimplemented }
        return try scanHandler(request, next)
    }
    
    var putCallCount: Int = 0
    var putHandler: ((Request, Handler) throws -> Response)?
    func put(_ request: Backend.Request, next: @Sendable (Backend.Application.Request) async throws -> Backend.Application.Response) async throws -> Backend.Response {
        putCallCount+=1
        guard let putHandler else { throw TestError.unimplemented }
        return try putHandler(request, next)
    }
}

final class DistrictControllerMock: DistrictControllerProtocol, @unchecked Sendable {
    
    init(
        getHandler: ((Request, Handler) throws -> Response)? = nil,
        queryHandler: ((Request, Handler) throws -> Response)? = nil,
        getToolsHandler: ((Request, Handler) throws -> Response)? = nil,
        postHandler: ((Request, Handler) throws -> Response)? = nil,
        putHandler: ((Request, Handler) throws -> Response)? = nil
    ) {
        self.getHandler = getHandler
        self.queryHandler = queryHandler
        self.getToolsHandler = getToolsHandler
        self.postHandler = postHandler
        self.putHandler = putHandler
    }
    
    var getCallCount: Int = 0
    var getHandler: ((Request, Handler) throws -> Response)?
    func get(_ request: Request, next: Handler) async throws -> Backend.Response {
        getCallCount+=1
        guard let getHandler else { throw TestError.unimplemented }
        return try getHandler(request, next)
    }
    
    var queryCallCount: Int = 0
    var queryHandler: ((Request, Handler) throws -> Response)?
    func query(_ request: Backend.Request, next: @Sendable (Backend.Application.Request) async throws -> Backend.Application.Response) async throws -> Backend.Response {
        queryCallCount+=1
        guard let queryHandler else { throw TestError.unimplemented }
        return try queryHandler(request, next)
    }
    
    var getToolsCallCount: Int = 0
    var getToolsHandler: ((Request, Handler) throws -> Response)?
    func getTools(_ request: Backend.Request, next: @Sendable (Backend.Application.Request) async throws -> Backend.Application.Response) async throws -> Backend.Response {
        getToolsCallCount+=1
        guard let getToolsHandler else { throw TestError.unimplemented }
        return try getToolsHandler(request, next)
    }
    
    var postCallCount: Int = 0
    var postHandler: ((Request, Handler) throws -> Response)?
    func post(_ request: Backend.Request, next: @Sendable (Backend.Application.Request) async throws -> Backend.Application.Response) async throws -> Backend.Response {
        postCallCount+=1
        guard let postHandler else { throw TestError.unimplemented }
        return try postHandler(request, next)
    }
    
    var putCallCount: Int = 0
    var putHandler: ((Request, Handler) throws -> Response)?
    func put(_ request: Backend.Request, next: @Sendable (Backend.Application.Request) async throws -> Backend.Application.Response) async throws -> Backend.Response {
        putCallCount+=1
        guard let putHandler else { throw TestError.unimplemented }
        return try putHandler(request, next)
    }
}

// MARK: - RouteControllerMock
final class RouteControllerMock: RouteControllerProtocol, @unchecked Sendable {

    init(
        getHandler: ((Request, Handler) throws -> Response)? = nil,
        queryHandler: ((Request, Handler) throws -> Response)? = nil,
        getCurrentHandler: ((Request, Handler) throws -> Response)? = nil,
        getIdsHandler: ((Request, Handler) throws -> Response)? = nil,
        postHandler: ((Request, Handler) throws -> Response)? = nil,
        putHandler: ((Request, Handler) throws -> Response)? = nil,
        deleteHandler: ((Request, Handler) throws -> Response)? = nil
    ) {
        self.getHandler = getHandler
        self.queryHandler = queryHandler
        self.getCurrentHandler = getCurrentHandler
        self.getIdsHandler = getIdsHandler
        self.postHandler = postHandler
        self.putHandler = putHandler
        self.deleteHandler = deleteHandler
    }

    var getCallCount: Int = 0
    var getHandler: ((Request, Handler) throws -> Response)?
    func get(_ request: Request, next: Handler) async throws -> Backend.Response {
        getCallCount += 1
        guard let getHandler else { throw TestError.unimplemented }
        return try getHandler(request, next)
    }

    var queryCallCount: Int = 0
    var queryHandler: ((Request, Handler) throws -> Response)?
    func query(_ request: Request, next: Handler) async throws -> Backend.Response {
        queryCallCount += 1
        guard let queryHandler else { throw TestError.unimplemented }
        return try queryHandler(request, next)
    }

    var getCurrentCallCount: Int = 0
    var getCurrentHandler: ((Request, Handler) throws -> Response)?
    func getCurrent(_ request: Request, next: Handler) async throws -> Backend.Response {
        getCurrentCallCount += 1
        guard let getCurrentHandler else { throw TestError.unimplemented }
        return try getCurrentHandler(request, next)
    }

    var getIdsCallCount: Int = 0
    var getIdsHandler: ((Request, Handler) throws -> Response)?
    func getIds(_ request: Request, next: Handler) async throws -> Backend.Response {
        getIdsCallCount += 1
        guard let getIdsHandler else { throw TestError.unimplemented }
        return try getIdsHandler(request, next)
    }

    var postCallCount: Int = 0
    var postHandler: ((Request, Handler) throws -> Response)?
    func post(_ request: Request, next: Handler) async throws -> Backend.Response {
        postCallCount += 1
        guard let postHandler else { throw TestError.unimplemented }
        return try postHandler(request, next)
    }

    var putCallCount: Int = 0
    var putHandler: ((Request, Handler) throws -> Response)?
    func put(_ request: Request, next: Handler) async throws -> Backend.Response {
        putCallCount += 1
        guard let putHandler else { throw TestError.unimplemented }
        return try putHandler(request, next)
    }

    var deleteCallCount: Int = 0
    var deleteHandler: ((Request, Handler) throws -> Response)?
    func delete(_ request: Request, next: Handler) async throws -> Backend.Response {
        deleteCallCount += 1
        guard let deleteHandler else { throw TestError.unimplemented }
        return try deleteHandler(request, next)
    }
}
 
// MARK: - LocationControllerMock
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

    var getCallCount: Int = 0
    var getHandler: ((Request, Handler) throws -> Response)?
    func get(_ request: Request, next: Handler) async throws -> Backend.Response {
        getCallCount += 1
        guard let getHandler else { throw TestError.unimplemented }
        return try getHandler(request, next)
    }

    var queryCallCount: Int = 0
    var queryHandler: ((Request, Handler) throws -> Response)?
    func query(_ request: Request, next: Handler) async throws -> Backend.Response {
        queryCallCount += 1
        guard let queryHandler else { throw TestError.unimplemented }
        return try queryHandler(request, next)
    }

    var putCallCount: Int = 0
    var putHandler: ((Request, Handler) throws -> Response)?
    func put(_ request: Request, next: Handler) async throws -> Backend.Response {
        putCallCount += 1
        guard let putHandler else { throw TestError.unimplemented }
        return try putHandler(request, next)
    }

    var deleteCallCount: Int = 0
    var deleteHandler: ((Request, Handler) throws -> Response)?
    func delete(_ request: Request, next: Handler) async throws -> Backend.Response {
        deleteCallCount += 1
        guard let deleteHandler else { throw TestError.unimplemented }
        return try deleteHandler(request, next)
    }
}

// MARK: - ProgramControllerMock
final class ProgramControllerMock: ProgramControllerProtocol, @unchecked Sendable {
    init(
        getLatestHandler: ((Request, Handler) throws -> Response)? = nil,
        getHandler: ((Request, Handler) throws -> Response)? = nil,
        queryHandler: ((Request, Handler) throws -> Response)? = nil,
        postHandler: ((Request, Handler) throws -> Response)? = nil,
        putHandler: ((Request, Handler) throws -> Response)? = nil,
        deleteHandler: ((Request, Handler) throws -> Response)? = nil
    ) {
        self.getLatestHandler = getLatestHandler
        self.getHandler = getHandler
        self.queryHandler = queryHandler
        self.postHandler = postHandler
        self.putHandler = putHandler
        self.deleteHandler = deleteHandler
    }

    private(set) var getLatestCallCount: Int = 0
    private var getLatestHandler: ((Request, Handler) throws -> Response)?
    func getLatest(request: Backend.Request, next: @Sendable (Backend.Application.Request) async throws -> Backend.Application.Response) async throws -> Backend.Response {
        getLatestCallCount += 1
        guard let getLatestHandler else { throw TestError.unimplemented }
        return try getLatestHandler(request, next)
    }

    private(set) var getCallCount: Int = 0
    private var getHandler: ((Request, Handler) throws -> Response)?
    func get(request: Backend.Request, next: @Sendable (Backend.Application.Request) async throws -> Backend.Application.Response) async throws -> Backend.Response {
        getCallCount += 1
        guard let getHandler else { throw TestError.unimplemented }
        return try getHandler(request, next)
    }

    private(set) var queryCallCount: Int = 0
    private var queryHandler: ((Request, Handler) throws -> Response)?
    func query(request: Backend.Request, next: @Sendable (Backend.Application.Request) async throws -> Backend.Application.Response) async throws -> Backend.Response {
        queryCallCount += 1
        guard let queryHandler else { throw TestError.unimplemented }
        return try queryHandler(request, next)
    }

    private(set) var postCallCount: Int = 0
    private var postHandler: ((Request, Handler) throws -> Response)?
    func post(request: Backend.Request, next: @Sendable (Backend.Application.Request) async throws -> Backend.Application.Response) async throws -> Backend.Response {
        postCallCount += 1
        guard let postHandler else { throw TestError.unimplemented }
        return try postHandler(request, next)
    }

    private(set) var putCallCount: Int = 0
    private var putHandler: ((Request, Handler) throws -> Response)?
    func put(request: Backend.Request, next: @Sendable (Backend.Application.Request) async throws -> Backend.Application.Response) async throws -> Backend.Response {
        putCallCount += 1
        guard let putHandler else { throw TestError.unimplemented }
        return try putHandler(request, next)
    }

    private(set) var deleteCallCount: Int = 0
    private var deleteHandler: ((Request, Handler) throws -> Response)?
    func delete(request: Backend.Request, next: @Sendable (Backend.Application.Request) async throws -> Backend.Application.Response) async throws -> Backend.Response {
        deleteCallCount += 1
        guard let deleteHandler else { throw TestError.unimplemented }
        return try deleteHandler(request, next)
    }
}

