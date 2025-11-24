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
        guard let getHandler else { fatalError("Unimplemented") }
        return try await getHandler(id)
    }

    private(set) var queryCallCount = 0
    private(set) var queryHandler: ((String) async throws -> [District])?
    func query(by festivalId: String) async throws -> [District] {
        queryCallCount+=1
        guard let queryHandler else { fatalError("Unimplemented") }
        return try await queryHandler(festivalId)
    }
    
    private(set)  var putCallCount = 0
    private(set) var putHandler: ((String, District) async throws -> District)?
    func put(id: String, item: District) async throws -> District {
        putCallCount+=1
        guard let putHandler else { fatalError("Unimplemented") }
        return try await putHandler(id, item)
    }
    
    private(set) var postCallCount = 0
    private(set) var postHandler: ((District) async throws -> District)?
    func post(item: District) async throws -> District {
        postCallCount+=1
        guard let postHandler else { fatalError("Unimplemented") }
        return try await postHandler(item)
    }
}

// MARK: - RouteRepositoryMock
struct RouteRepositoryMock: RouteRepositoryProtocol {
    static let response = Route(
        id: "id", districtId: "districtId", start: SimpleTime(hour: 0, minute: 0),
        goal: SimpleTime(hour: 23, minute: 59))

    func get(id: String) async throws -> Route? { Self.response }

    func query(by districtId: String) async throws -> [Route] { [Self.response] }

    func post(_ route: Route) async throws {}

    func put(_ route: Route) async throws {}

    func delete(id: String) async throws {}
}

// MARK: - LocationRepositoryMock
struct LocationRepositoryMock: LocationRepositoryProtocol {
    static let response = FloatLocation(
        districtId: "districtId", coordinate: Coordinate(latitude: 0, longitude: 0),
        timestamp: Date.now)

    func get(id: String) async throws -> FloatLocation? { Self.response }

    func getAll() async throws -> [FloatLocation] { [Self.response] }

    func put(_ location: FloatLocation) async throws {}

    func delete(districtId: String) async throws {}
}
