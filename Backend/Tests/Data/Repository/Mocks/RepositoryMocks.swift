//
//  RepositoryMocks.swift
//  MaTool
//
//  Created by 松下和也 on 2025/11/14.
//

import Foundation
import Shared

@testable import Backend

// MARK: - FestivalRepositoryMock
final class FestivalRepositoryMock: FestivalRepositoryProtocol, @unchecked Sendable {
    
    init(
        getHandler: ((String) throws -> Festival?)? = nil,
        scanHandler: (() throws -> [Festival])? = nil,
        putHandler: ((Festival) throws -> Festival)? = nil) {
        self.getHandler = getHandler
        self.scanHandler = scanHandler
        self.putHandler = putHandler
    }
    
    private(set) var getCallCount = 0
    private(set) var getHandler: ((String) throws -> Festival?)?
    func get(id: String) async throws -> Festival? {
        getCallCount+=1
        guard let getHandler else { throw TestError.unimplemented }
        return try getHandler(id)
    }

    private(set) var scanCallCount = 0
    private(set) var scanHandler: (() throws -> [Festival])?
    func scan() async throws -> [Festival] {
        scanCallCount+=1
        guard let scanHandler else { throw TestError.unimplemented }
        return try scanHandler()
    }

    private(set) var putCount = 0
    private var putHandler: ((Festival) throws -> Festival)?
    func put(_ item: Festival) async throws -> Festival {
        putCount+=1
        guard let putHandler else { throw TestError.unimplemented }
        return try putHandler(item)
    }
}

// MARK: - DistrictRepositoryMock
final class DistrictRepositoryMock: DistrictRepositoryProtocol, @unchecked Sendable {
    
    init(getCallCount: Int = 0, getHandler: ((String) async throws -> District?)? = nil, queryCallCount: Int = 0, queryHandler: ((String) async throws -> [District])? = nil, putCallCount: Int = 0, putHandler: ((String, District) async throws -> District)? = nil, postCallCount: Int = 0, postHandler: ((District) async throws -> District)? = nil) {
        self.getCallCount = getCallCount
        self.getHandler = getHandler
        self.queryCallCount = queryCallCount
        self.queryHandler = queryHandler
        self.putCallCount = putCallCount
        self.putHandler = putHandler
        self.postCallCount = postCallCount
        self.postHandler = postHandler
    }
    
    private(set) var getCallCount = 0
    private(set) var getHandler: ((String) async throws -> District?)?
    func get(id: String) async throws -> District? {
        getCallCount+=1
        guard let getHandler else { throw TestError.unimplemented }
        return try await getHandler(id)
    }

    private(set) var queryCallCount = 0
    private(set) var queryHandler: ((String) async throws -> [District])?
    func query(by festivalId: String) async throws -> [District] {
        queryCallCount+=1
        guard let queryHandler else { throw TestError.unimplemented }
        return try await queryHandler(festivalId)
    }
    
    private(set)  var putCallCount = 0
    private(set) var putHandler: ((String, District) async throws -> District)?
    func put(id: String, item: District) async throws -> District {
        putCallCount+=1
        guard let putHandler else { throw TestError.unimplemented }
        return try await putHandler(id, item)
    }
    
    private(set) var postCallCount = 0
    private(set) var postHandler: ((District) async throws -> District)?
    func post(item: District) async throws -> District {
        postCallCount+=1
        guard let postHandler else { throw TestError.unimplemented }
        return try await postHandler(item)
    }
}

// MARK: - RouteRepositoryMock
final class RouteRepositoryMock: RouteRepositoryProtocol, @unchecked Sendable {
    init(
        getHandler: ((String) async throws -> Route?)? = nil,
        queryHandler: ((String) async throws -> [Route])? = nil,
        postHandler: ((Route) async throws -> Void)? = nil,
        putHandler: ((Route) async throws -> Void)? = nil,
        deleteHandler: ((String) async throws -> Void)? = nil
    ) {
        self.getHandler = getHandler
        self.queryHandler = queryHandler
        self.postHandler = postHandler
        self.putHandler = putHandler
        self.deleteHandler = deleteHandler
    }
    
    private(set) var getCallCount = 0
    private(set) var getHandler: ((String) async throws -> Route?)?
    func get(id: String) async throws -> Route? {
        getCallCount += 1
        guard let getHandler else { throw TestError.unimplemented }
        return try await getHandler(id)
    }
    
    private(set) var queryCallCount = 0
    private(set) var queryHandler: ((String) async throws -> [Route])?
    func query(by districtId: String) async throws -> [Route] {
        queryCallCount += 1
        guard let queryHandler else { throw TestError.unimplemented }
        return try await queryHandler(districtId)
    }
    
    private(set) var postCallCount = 0
    private(set) var postHandler: ((Route) async throws -> Void)?
    func post(_ route: Route) async throws {
        postCallCount += 1
        guard let postHandler else { throw TestError.unimplemented }
        try await postHandler(route)
    }
    
    private(set) var putCallCount = 0
    private(set) var putHandler: ((Route) async throws -> Void)?
    func put(_ route: Route) async throws {
        putCallCount += 1
        guard let putHandler else { throw TestError.unimplemented }
        try await putHandler(route)
    }
    
    private(set) var deleteCallCount = 0
    private(set) var deleteHandler: ((String) async throws -> Void)?
    func delete(id: String) async throws {
        deleteCallCount += 1
        guard let deleteHandler else { throw TestError.unimplemented }
        try await deleteHandler(id)
    }
}

// MARK: - LocationRepositoryMock
final class LocationRepositoryMock: LocationRepositoryProtocol, @unchecked Sendable {
    init(
        getHandler: ((String) async throws -> FloatLocation?)? = nil,
        getAllHandler: (() async throws -> [FloatLocation])? = nil,
        putHandler: ((FloatLocation) async throws -> Void)? = nil,
        deleteHandler: ((String) async throws -> Void)? = nil
    ) {
        self.getHandler = getHandler
        self.getAllHandler = getAllHandler
        self.putHandler = putHandler
        self.deleteHandler = deleteHandler
    }
    
    private(set) var getCallCount = 0
    private(set) var getHandler: ((String) async throws -> FloatLocation?)?
    func get(id: String) async throws -> FloatLocation? {
        getCallCount += 1
        guard let getHandler else { throw TestError.unimplemented }
        return try await getHandler(id)
    }
    
    private(set) var getAllCallCount = 0
    private(set) var getAllHandler: (() async throws -> [FloatLocation])?
    func getAll() async throws -> [FloatLocation] {
        getAllCallCount += 1
        guard let getAllHandler else { throw TestError.unimplemented }
        return try await getAllHandler()
    }
    
    private(set) var putCallCount = 0
    private(set) var putHandler: ((FloatLocation) async throws -> Void)?
    func put(_ location: FloatLocation) async throws {
        putCallCount += 1
        guard let putHandler else { throw TestError.unimplemented }
        try await putHandler(location)
    }
    
    private(set) var deleteCallCount = 0
    private(set) var deleteHandler: ((String) async throws -> Void)?
    func delete(districtId: String) async throws {
        deleteCallCount += 1
        guard let deleteHandler else { throw TestError.unimplemented }
        try await deleteHandler(districtId)
    }
}
