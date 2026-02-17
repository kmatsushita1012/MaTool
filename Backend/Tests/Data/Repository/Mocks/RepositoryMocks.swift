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
        putHandler: ((Festival) throws -> Festival)? = nil
    ) {
        self.getHandler = getHandler
        self.scanHandler = scanHandler
        self.putHandler = putHandler
    }

    // get
    private(set) var getCallCount = 0
    private(set) var getHandler: ((String) throws -> Festival?)?
    func get(id: String) async throws -> Festival? {
        getCallCount += 1
        guard let getHandler else { throw TestError.unimplemented }
        return try getHandler(id)
    }

    // scan
    private(set) var scanCallCount = 0
    private(set) var scanHandler: (() throws -> [Festival])?
    func scan() async throws -> [Festival] {
        scanCallCount += 1
        guard let scanHandler else { throw TestError.unimplemented }
        return try scanHandler()
    }

    // put
    private(set) var putCount = 0
    private var putHandler: ((Festival) throws -> Festival)?
    func put(_ item: Festival) async throws -> Festival {
        putCount += 1
        guard let putHandler else { throw TestError.unimplemented }
        return try putHandler(item)
    }
}

// MARK: - DistrictRepositoryMock
final class DistrictRepositoryMock: DistrictRepositoryProtocol, @unchecked Sendable {
    init(
        getCallCount: Int = 0,
        getHandler: ((String) async throws -> District?)? = nil,
        queryCallCount: Int = 0,
        queryHandler: ((String) async throws -> [District])? = nil,
        putCallCount: Int = 0,
        putHandler: ((String, District) async throws -> District)? = nil,
        postCallCount: Int = 0,
        postHandler: ((District) async throws -> District)? = nil
    ) {
        self.getCallCount = getCallCount
        self.getHandler = getHandler
        self.queryCallCount = queryCallCount
        self.queryHandler = queryHandler
        self.putCallCount = putCallCount
        self.putHandler = putHandler
        self.postCallCount = postCallCount
        self.postHandler = postHandler
    }

    // get
    private(set) var getCallCount = 0
    private(set) var getHandler: ((String) async throws -> District?)?
    func get(id: String) async throws -> District? {
        getCallCount += 1
        guard let getHandler else { throw TestError.unimplemented }
        return try await getHandler(id)
    }

    // query
    private(set) var queryCallCount = 0
    private(set) var queryHandler: ((String) async throws -> [District])?
    func query(by festivalId: String) async throws -> [District] {
        queryCallCount += 1
        guard let queryHandler else { throw TestError.unimplemented }
        return try await queryHandler(festivalId)
    }

    // put
    private(set) var putCallCount = 0
    private(set) var putHandler: ((String, District) async throws -> District)?
    func put(id: String, item: District) async throws -> District {
        putCallCount += 1
        guard let putHandler else { throw TestError.unimplemented }
        return try await putHandler(id, item)
    }

    // post
    private(set) var postCallCount = 0
    private(set) var postHandler: ((District) async throws -> District)?
    func post(item: District) async throws -> District {
        postCallCount += 1
        guard let postHandler else { throw TestError.unimplemented }
        return try await postHandler(item)
    }
}

// MARK: - RouteRepositoryMock
final class RouteRepositoryMock: RouteRepositoryProtocol, @unchecked Sendable {
    init(
        getHandler: ((String) async throws -> Route?)? = nil,
        queryHandler: ((String) async throws -> [Route])? = nil,
        queryYearHandler: ((String, Int) async throws -> [Route])? = nil,
        postHandler: ((Route) async throws -> Route)? = nil,
        putHandler: ((Route) async throws -> Route)? = nil,
        deleteHandler: ((String) async throws -> Void)? = nil
    ) {
        self.getHandler = getHandler
        self.queryHandler = queryHandler
        self.queryYearHandler = queryYearHandler
        self.postHandler = postHandler
        self.putHandler = putHandler
        self.deleteHandler = deleteHandler
    }

    // get
    private(set) var getCallCount = 0
    private(set) var getHandler: ((String) async throws -> Route?)?
    func get(id: String) async throws -> Route? {
        getCallCount += 1
        guard let getHandler else { throw TestError.unimplemented }
        return try await getHandler(id)
    }

    // query by year
    private(set) var queryYearCallCount = 0
    private(set) var queryYearHandler: ((String, Int) async throws -> [Route])?
    func query(by districtId: String, year: Int) async throws -> [Shared.Route] {
        queryYearCallCount += 1
        guard let queryYearHandler else { throw TestError.unimplemented }
        return try await queryYearHandler(districtId, year)
    }

    // query
    private(set) var queryCallCount = 0
    private(set) var queryHandler: ((String) async throws -> [Route])?
    func query(by districtId: String) async throws -> [Shared.Route] {
        queryCallCount += 1
        guard let queryHandler else { throw TestError.unimplemented }
        return try await queryHandler(districtId)
    }

    // post
    private(set) var postCallCount = 0
    private(set) var postHandler: ((Route) async throws -> Route)?
    func post(_ route: Route) async throws -> Route {
        postCallCount += 1
        guard let postHandler else { throw TestError.unimplemented }
        return try await postHandler(route)
    }

    // put
    private(set) var putCallCount = 0
    private(set) var putHandler: ((Route) async throws -> Route)?
    func put(_ route: Route) async throws -> Route {
        putCallCount += 1
        guard let putHandler else { throw TestError.unimplemented }
        return try await putHandler(route)
    }

    // delete
    private(set) var deleteCallCount = 0
    private(set) var deleteHandler: ((String) async throws -> Void)?
    func delete(id: String) async throws {
        deleteCallCount += 1
        guard let deleteHandler else { throw TestError.unimplemented }
        try await deleteHandler(id)
        return
    }
}

// MARK: - LocationRepositoryMock
final class LocationRepositoryMock: LocationRepositoryProtocol, @unchecked Sendable {
    init(
        getHandler: ((Festival.ID, District.ID) async throws -> FloatLocation?)? = nil,
        queryHandler: ((Festival.ID) async throws -> [FloatLocation])? = nil,
        postHandler: ((FloatLocation, Festival.ID) async throws -> FloatLocation)? = nil,
        putHandler: ((FloatLocation, Festival.ID) async throws -> FloatLocation)? = nil,
        deleteHandler: ((Festival.ID, District.ID) async throws -> Void)? = nil
    ) {
        self.getHandler = getHandler
        self.queryHandler = queryHandler
        self.postHandler = postHandler
        self.putHandler = putHandler
        self.deleteHandler = deleteHandler
    }

    // get
    private(set) var getCallCount = 0
    private var getHandler: ((Festival.ID, District.ID) async throws -> FloatLocation?)?
    func get(festivalId: Festival.ID, districtId: District.ID) async throws -> Shared.FloatLocation? {
        getCallCount += 1
        guard let handler = getHandler else { throw TestError.unimplemented }
        return try await handler(festivalId, districtId)
    }

    // query
    private(set) var queryCallCount = 0
    private var queryHandler: ((Festival.ID) async throws -> [FloatLocation])?
    func query(by festivalId: Festival.ID) async throws -> [Shared.FloatLocation] {
        queryCallCount += 1
        guard let queryHandler else { throw TestError.unimplemented }
        return try await queryHandler(festivalId)
    }

    // post
    private(set) var postCallCount = 0
    private var postHandler: ((FloatLocation, Festival.ID) async throws -> FloatLocation)?
    func post(_ location: Shared.FloatLocation, festivalId: Shared.Festival.ID) async throws -> Shared.FloatLocation {
        postCallCount += 1
        guard let postHandler else { throw TestError.unimplemented }
        return try await postHandler(location, festivalId)
    }

    // put
    private(set) var putCallCount = 0
    private var putHandler: ((FloatLocation, Festival.ID) async throws -> FloatLocation)?
    func put(_ location: Shared.FloatLocation, festivalId: Shared.Festival.ID) async throws -> Shared.FloatLocation {
        putCallCount += 1
        guard let putHandler else { throw TestError.unimplemented }
        return try await putHandler(location, festivalId)
    }

    // delete
    private(set) var deleteCallCount = 0
    private var deleteHandler: ((Festival.ID, District.ID) async throws -> Void)?
    func delete(festivalId: Festival.ID, districtId: District.ID) async throws {
        deleteCallCount += 1
        guard let deleteHandler else { throw TestError.unimplemented }
        try await deleteHandler(festivalId, districtId)
    }
}

// MARK: - CheckpointRepositoryMock
final class CheckpointRepositoryMock: CheckpointRepositoryProtocol, @unchecked Sendable {
    init(
        getHandler: ((Checkpoint.ID) async throws -> Checkpoint?)? = nil,
        queryHandler: ((Festival.ID) async throws -> [Checkpoint])? = nil,
        postHandler: ((Checkpoint) async throws -> Checkpoint)? = nil,
        putHandler: ((Checkpoint) async throws -> Checkpoint)? = nil,
        deleteHandler: ((Checkpoint) async throws -> Void)? = nil
    ) {
        self.getHandler = getHandler
        self.queryHandler = queryHandler
        self.postHandler = postHandler
        self.putHandler = putHandler
        self.deleteHandler = deleteHandler
    }

    // get
    private(set) var getCallCount = 0
    private var getHandler: ((Checkpoint.ID) async throws -> Checkpoint?)?
    func get(id: Checkpoint.ID) async throws -> Checkpoint? {
        getCallCount += 1
        guard let getHandler else { throw TestError.unimplemented }
        return try await getHandler(id)
    }

    // query
    private(set) var queryCallCount = 0
    private var queryHandler: ((Festival.ID) async throws -> [Checkpoint])?
    func query(by festivalId: Festival.ID) async throws -> [Checkpoint] {
        queryCallCount += 1
        guard let queryHandler else { throw TestError.unimplemented }
        return try await queryHandler(festivalId)
    }

    // post
    private(set) var postCallCount = 0
    private var postHandler: ((Checkpoint) async throws -> Checkpoint)?
    func post(_ item: Checkpoint) async throws -> Checkpoint {
        postCallCount += 1
        guard let postHandler else { throw TestError.unimplemented }
        return try await postHandler(item)
    }

    // put
    private(set) var putCallCount = 0
    private var putHandler: ((Checkpoint) async throws -> Checkpoint)?
    func put(_ item: Checkpoint) async throws -> Checkpoint {
        putCallCount += 1
        guard let putHandler else { throw TestError.unimplemented }
        return try await putHandler(item)
    }

    // delete
    private(set) var deleteCallCount = 0
    private var deleteHandler: ((Checkpoint) async throws -> Void)?
    func delete(_ item: Shared.Checkpoint) async throws {
        deleteCallCount += 1
        guard let deleteHandler else { throw TestError.unimplemented }
        try await deleteHandler(item)
    }
}

// MARK: - HazardSectionRepositoryMock
final class HazardSectionRepositoryMock: HazardSectionRepositoryProtocol, @unchecked Sendable {
    init(
        getHandler: ((HazardSection.ID) async throws -> HazardSection?)? = nil,
        queryHandler: ((Festival.ID) async throws -> [HazardSection])? = nil,
        postHandler: ((HazardSection) async throws -> HazardSection)? = nil,
        putHandler: ((HazardSection) async throws -> HazardSection)? = nil,
        deleteHandler: ((HazardSection) async throws -> Void)? = nil
    ) {
        self.getHandler = getHandler
        self.queryHandler = queryHandler
        self.postHandler = postHandler
        self.putHandler = putHandler
        self.deleteHandler = deleteHandler
    }

    // get
    private(set) var getCallCount = 0
    private var getHandler: ((HazardSection.ID) async throws -> HazardSection?)?
    func get(id: HazardSection.ID) async throws -> HazardSection? {
        getCallCount += 1
        guard let getHandler else { throw TestError.unimplemented }
        return try await getHandler(id)
    }

    // query
    private(set) var queryCallCount = 0
    private var queryHandler: ((Festival.ID) async throws -> [HazardSection])?
    func query(by festivalId: Festival.ID) async throws -> [HazardSection] {
        queryCallCount += 1
        guard let queryHandler else { throw TestError.unimplemented }
        return try await queryHandler(festivalId)
    }

    // post
    private(set) var postCallCount = 0
    private var postHandler: ((HazardSection) async throws -> HazardSection)?
    func post(_ item: HazardSection) async throws -> HazardSection {
        postCallCount += 1
        guard let postHandler else { throw TestError.unimplemented }
        return try await postHandler(item)
    }

    // put
    private(set) var putCallCount = 0
    private var putHandler: ((HazardSection) async throws -> HazardSection)?
    func put(_ item: HazardSection) async throws -> HazardSection {
        putCallCount += 1
        guard let putHandler else { throw TestError.unimplemented }
        return try await putHandler(item)
    }

    // delete
    private(set) var deleteCallCount = 0
    private var deleteHandler: ((HazardSection) async throws -> Void)?
    func delete(_ item: Shared.HazardSection) async throws {
        deleteCallCount += 1
        guard let deleteHandler else { throw TestError.unimplemented }
        try await deleteHandler(item)
    }
}

// MARK: - PerformanceRepositoryMock
final class PerformanceRepositoryMock: PerformanceRepositoryProtocol, @unchecked Sendable {
    init(
        getHandler: ((Performance.ID) async throws -> Performance?)? = nil,
        queryHandler: ((Festival.ID) async throws -> [Performance])? = nil,
        postHandler: ((Performance) async throws -> Performance)? = nil,
        putHandler: ((Performance) async throws -> Performance)? = nil,
        deleteHandler: ((Performance) async throws -> Void)? = nil
    ) {
        self.getHandler = getHandler
        self.queryHandler = queryHandler
        self.postHandler = postHandler
        self.putHandler = putHandler
        self.deleteHandler = deleteHandler
    }

    // get
    private(set) var getCallCount = 0
    private var getHandler: ((Performance.ID) async throws -> Performance?)?
    func get(id: Performance.ID) async throws -> Performance? {
        getCallCount += 1
        guard let getHandler else { throw TestError.unimplemented }
        return try await getHandler(id)
    }

    // query
    private(set) var queryCallCount = 0
    private var queryHandler: ((Festival.ID) async throws -> [Performance])?
    func query(by festivalId: Festival.ID) async throws -> [Performance] {
        queryCallCount += 1
        guard let queryHandler else { throw TestError.unimplemented }
        return try await queryHandler(festivalId)
    }

    // post
    private(set) var postCallCount = 0
    private var postHandler: ((Performance) async throws -> Performance)?
    func post(_ item: Performance) async throws -> Performance {
        postCallCount += 1
        guard let postHandler else { throw TestError.unimplemented }
        return try await postHandler(item)
    }

    // put
    private(set) var putCallCount = 0
    private var putHandler: ((Performance) async throws -> Performance)?
    func put(_ item: Performance) async throws -> Performance {
        putCallCount += 1
        guard let putHandler else { throw TestError.unimplemented }
        return try await putHandler(item)
    }

    // delete
    private(set) var deleteCallCount = 0
    private var deleteHandler: ((Performance) async throws -> Void)?
    func delete(_ item: Shared.Performance) async throws {
        deleteCallCount += 1
        guard let deleteHandler else { throw TestError.unimplemented }
        try await deleteHandler(item)
    }
}

// MARK: - PeriodRepositoryMock (backend)
final class PeriodRepositoryBackendMock: PeriodRepositoryProtocol, @unchecked Sendable {
    init(
        getHandler: ((Period.ID) async throws -> Period?)? = nil,
        queryYearHandler: ((Festival.ID, Int) async throws -> [Period])? = nil,
        queryHandler: ((Festival.ID) async throws -> [Period])? = nil,
        postHandler: ((Period) async throws -> Period)? = nil,
        putHandler: ((Period) async throws -> Period)? = nil,
        deleteHandler: ((Festival.ID, SimpleDate) async throws -> Void)? = nil
    ) {
        self.getHandler = getHandler
        self.queryYearHandler = queryYearHandler
        self.queryHandler = queryHandler
        self.postHandler = postHandler
        self.putHandler = putHandler
        self.deleteHandler = deleteHandler
    }

    // get
    private(set) var getCallCount = 0
    private var getHandler: ((Period.ID) async throws -> Period?)?
    func get(id: Period.ID) async throws -> Period? {
        getCallCount += 1
        guard let getHandler else { throw TestError.unimplemented }
        return try await getHandler(id)
    }

    // query by year
    private(set) var queryYearCallCount = 0
    private var queryYearHandler: ((Festival.ID, Int) async throws -> [Period])?
    func query(by festivalId: String, year: Int) async throws -> [Period] {
        queryYearCallCount += 1
        guard let queryYearHandler else { throw TestError.unimplemented }
        return try await queryYearHandler(festivalId, year)
    }

    // query
    private(set) var queryCallCount = 0
    private var queryHandler: ((Festival.ID) async throws -> [Period])?
    func query(by festivalId: String) async throws -> [Period] {
        queryCallCount += 1
        guard let queryHandler else { throw TestError.unimplemented }
        return try await queryHandler(festivalId)
    }

    // post
    private(set) var postCallCount = 0
    private var postHandler: ((Period) async throws -> Period)?
    func post(_ Period: Period) async throws -> Period {
        postCallCount += 1
        guard let postHandler else { throw TestError.unimplemented }
        return try await postHandler(Period)
    }

    // put
    private(set) var putCallCount = 0
    private var putHandler: ((Period) async throws -> Period)?
    func put(_ Period: Period) async throws -> Period {
        putCallCount += 1
        guard let putHandler else { throw TestError.unimplemented }
        return try await putHandler(Period)
    }

    // delete
    private(set) var deleteCallCount = 0
    private var deleteHandler: ((Festival.ID, SimpleDate) async throws -> Void)?
    func delete(festivalId: String, date: SimpleDate) async throws {
        deleteCallCount += 1
        guard let deleteHandler else { throw TestError.unimplemented }
        try await deleteHandler(festivalId, date)
    }
}

// MARK: - PointRepositoryMock
final class PointRepositoryMock: PointRepositoryProtocol, @unchecked Sendable {
    init(
        queryHandler: ((Route.ID) async throws -> [Point])? = nil,
        postItemHandler: ((Point) async throws -> Point)? = nil,
        putItemHandler: ((Point) async throws -> Point)? = nil,
        deleteItemHandler: ((Point) async throws -> Void)? = nil,
        deleteByRouteHandler: ((Route.ID) async throws -> Void)? = nil
    ) {
        self.queryHandler = queryHandler
        self.postItemHandler = postItemHandler
        self.putItemHandler = putItemHandler
        self.deleteItemHandler = deleteItemHandler
        self.deleteByRouteHandler = deleteByRouteHandler
    }

    // query
    private(set) var queryCallCount = 0
    private var queryHandler: ((Route.ID) async throws -> [Point])?
    func query(by routeId: Route.ID) async throws -> [Point] {
        queryCallCount += 1
        guard let queryHandler else { throw TestError.unimplemented }
        return try await queryHandler(routeId)
    }

    // post item
    private(set) var postItemCallCount = 0
    private var postItemHandler: ((Point) async throws -> Point)?
    func post(_ item: Shared.Point) async throws -> Shared.Point {
        postItemCallCount += 1
        guard let postItemHandler else { throw TestError.unimplemented }
        return try await postItemHandler(item)
    }

    // put item
    private(set) var putItemCallCount = 0
    private var putItemHandler: ((Point) async throws -> Point)?
    func put(_ item: Shared.Point) async throws -> Shared.Point {
        putItemCallCount += 1
        guard let putItemHandler else { throw TestError.unimplemented }
        return try await putItemHandler(item)
    }

    // delete item
    private(set) var deleteItemCallCount = 0
    private var deleteItemHandler: ((Point) async throws -> Void)?
    func delete(_ item: Shared.Point) async throws {
        deleteItemCallCount += 1
        guard let deleteItemHandler else { throw TestError.unimplemented }
        try await deleteItemHandler(item)
    }

    // delete by route
    private(set) var deleteByRouteCallCount = 0
    private var deleteByRouteHandler: ((Route.ID) async throws -> Void)?
    func delete(by routeId: Shared.Route.ID) async throws {
        deleteByRouteCallCount += 1
        guard let deleteByRouteHandler else { throw TestError.unimplemented }
        try await deleteByRouteHandler(routeId)
    }
}

