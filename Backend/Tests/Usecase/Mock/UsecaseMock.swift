//
//  UsecaseMock.swift
//  matool-backend
//
//  Created by 松下和也 on 2025/11/24.
//

import Testing
@testable import Backend
import Shared
import Foundation

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

final class DistrictUsecaseMock: DistrictUsecaseProtocol, @unchecked Sendable {
    init(
        queryHandler: ((String) throws -> [Shared.District])? = nil,
        getHandler: ((String) throws -> Shared.District)? = nil,
        postHandler: ((Shared.UserRole, String, String, String) throws -> Shared.District)? = nil,
        putHandler: ((String, Shared.District, Shared.UserRole) throws -> Shared.District)? = nil,
        getToolsHandler: ((String, Shared.UserRole) throws -> Shared.DistrictTool)? = nil
    ) {
        self.queryHandler = queryHandler
        self.getHandler = getHandler
        self.postHandler = postHandler
        self.putHandler = putHandler
        self.getToolsHandler = getToolsHandler
    }

    private(set) var queryCallCount = 0
    private var queryHandler: ((String) throws -> [Shared.District])? = nil
    func query(by regionId: String) async throws -> [Shared.District] {
        queryCallCount += 1
        guard let queryHandler else { fatalError("Unimplemented") }
        return try queryHandler(regionId)
    }

    private(set) var getCallCount = 0
    private var getHandler: ((String) throws -> Shared.District)? = nil
    func get(_ id: String) async throws -> Shared.District {
        getCallCount += 1
        guard let getHandler else { fatalError("Unimplemented") }
        return try getHandler(id)
    }

    private(set) var postCallCount = 0
    private var postHandler: ((Shared.UserRole, String, String, String) throws -> Shared.District)? = nil
    func post(user: Shared.UserRole, headquarterId: String, newDistrictName: String, email: String) async throws -> Shared.District {
        postCallCount += 1
        guard let postHandler else { fatalError("Unimplemented") }
        return try postHandler(user, headquarterId, newDistrictName, email)
    }

    private(set) var putCallCount = 0
    private var putHandler: ((String, Shared.District, Shared.UserRole) throws -> Shared.District)? = nil
    func put(id: String, item: Shared.District, user: Shared.UserRole) async throws -> Shared.District {
        putCallCount += 1
        guard let putHandler else { fatalError("Unimplemented") }
        return try putHandler(id, item, user)
    }

    private(set) var getToolsCallCount = 0
    private var getToolsHandler: ((String, Shared.UserRole) throws -> Shared.DistrictTool)? = nil
    func getTools(id: String, user: Shared.UserRole) async throws -> Shared.DistrictTool {
        getToolsCallCount += 1
        guard let getToolsHandler else { fatalError("Unimplemented") }
        return try getToolsHandler(id, user)
    }
}

final class LocationUsecaseMock: LocationUsecaseProtocol, @unchecked Sendable {
    
    init(
        queryHandler: ((String, UserRole, Date) throws -> [Shared.FloatLocationGetDTO])? = nil,
        getHandler: ((String, UserRole) throws -> Shared.FloatLocationGetDTO)? = nil,
        putHandler: ((Shared.FloatLocation, Shared.UserRole) throws -> Shared.FloatLocation)? = nil,
        deleteHandler: ((String, Shared.UserRole) throws -> Void)? = nil
    ) {
        self.queryHandler = queryHandler
        self.putHandler = putHandler
        self.deleteHandler = deleteHandler
    }

    private(set) var queryCallCount = 0
    private var queryHandler: ((String, UserRole, Date) throws -> [Shared.FloatLocationGetDTO])? = nil
    func  query(by festivalId: String, user: Shared.UserRole, now: Date) async throws -> [Shared.FloatLocationGetDTO] {
        queryCallCount += 1
        guard let queryHandler else { throw TestError.unimplemented }
        return try queryHandler(festivalId, user, now)
    }

    private(set) var getCallCount = 0
    private var getHandler: ((String, UserRole) throws -> Shared.FloatLocationGetDTO)? = nil
    func get(_ id: String, user: UserRole) async throws -> Shared.FloatLocationGetDTO {
        getCallCount += 1
        guard let getHandler else { throw TestError.unimplemented }
        return try getHandler(id, user)
    }

    private(set) var putCallCount = 0
    private var putHandler: ((Shared.FloatLocation, Shared.UserRole) throws -> Shared.FloatLocation)? = nil
    func put(_ location: Shared.FloatLocation, user: Shared.UserRole) async throws -> Shared.FloatLocation {
        putCallCount += 1
        guard let putHandler else { throw TestError.unimplemented }
        return try putHandler(location, user)
    }

    private(set) var deleteCallCount = 0
    private var deleteHandler: ((String, Shared.UserRole) throws -> Void)? = nil
    func delete(_ id: String, user: Shared.UserRole) async throws {
        deleteCallCount += 1
        guard let deleteHandler else { throw TestError.unimplemented }
        try deleteHandler(id, user)
    }
}
