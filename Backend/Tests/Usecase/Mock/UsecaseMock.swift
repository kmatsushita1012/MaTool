//
//  UsecaseMock.swift
//  matool-backend
//
//  Created by 松下和也 on 2025/11/24.
//

import Testing
@testable import Backend
import Shared

final class FestivalUsecaseMock: FestivalUsecaseProtocol, @unchecked Sendable {
    
    init(scanCallCount: Int = 0, scanHandler: (() throws -> [Festival])? = nil, getCallCount: Int = 0, getHandler: ((String) throws -> Shared.Festival)? = nil, putCallCount: Int = 0, putHandler: ((Shared.Festival, Shared.UserRole) throws -> Shared.Festival)? = nil) {
        self.scanCallCount = scanCallCount
        self.scanHandler = scanHandler
        self.getCallCount = getCallCount
        self.getHandler = getHandler
        self.putCallCount = putCallCount
        self.putHandler = putHandler
    }
    
    private(set) var scanCallCount = 0
    private var scanHandler: (() throws -> [Festival])? = nil
    func scan() async throws -> [Festival] {
        scanCallCount+=1
        guard let scanHandler else { fatalError("Unimplemented") }
        return try scanHandler()
    }
    
    private(set) var getCallCount = 0
    private var getHandler: ((String) throws -> Shared.Festival)? = nil
    func get(_ id: String) async throws -> Shared.Festival {
        getCallCount+=1
        guard let getHandler else { fatalError("Unimplemented")}
        return try getHandler(id)
        
    }
    
    private(set) var putCallCount = 0
    private var putHandler: ((Shared.Festival, Shared.UserRole) throws -> Shared.Festival)? = nil
    func put(_ festival: Shared.Festival, user: Shared.UserRole) async throws -> Shared.Festival {
        putCallCount+=1
        guard let putHandler else { fatalError("Unimplemented")}
        return try putHandler(festival, user)
    }
}
