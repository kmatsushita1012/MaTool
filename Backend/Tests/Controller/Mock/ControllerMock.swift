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
