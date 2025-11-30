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
    
    init(getCallCount: Int = 0, getHandler: ((String) async throws -> Festival?)? = nil, scanCallCount: Int = 0, scanHandler: (() async throws -> [Festival])? = nil, putCount: Int = 0, putHandler: ((Festival) async throws -> Festival)? = nil) {
        self.getCallCount = getCallCount
        self.getHandler = getHandler
        self.scanCallCount = scanCallCount
        self.scanHandler = scanHandler
        self.putCount = putCount
        self.putHandler = putHandler
    }
    
    private(set) var getCallCount = 0
    private(set) var getHandler: ((String) async throws -> Festival?)?
    func get(id: String) async throws -> Festival? {
        getCallCount+=1
        guard let getHandler else { fatalError("Unimplemented")}
        return try await getHandler(id)
    }

    private(set) var scanCallCount = 0
    private(set) var scanHandler: (() async throws -> [Festival])?
    func scan() async throws -> [Festival] {
        scanCallCount+=1
        guard let scanHandler else { fatalError("Unimplemented")}
        return try await scanHandler()
    }

    private(set) var putCount = 0
    private var putHandler: ((Festival) async throws -> Festival)?
    func put(_ item: Festival) async throws -> Festival {
        putCount+=1
        guard let putHandler else { fatalError("Unimplemented")}
        return try await putHandler(item)
    }
}

// MARK: - DistrictRepositoryMock
struct DistrictRepositoryMock: DistrictRepositoryProtocol {
    static let response = District(
        id: "id", name: "name", festivalId: "festivalId", visibility: .all)

    func get(id: String) async throws -> District? {
        return Self.response
    }

    func query(by festivalId: String) async throws -> [District] {
        return [Self.response]
    }

    func put(id: String, item: District) async throws {}

    func post(item: District) async throws {}
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
