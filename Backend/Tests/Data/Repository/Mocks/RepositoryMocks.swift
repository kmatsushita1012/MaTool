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

    private(set) var getCallCount = 0
    private let getHandler: ((String) throws -> Festival?)?
    func get(id: String) async throws -> Festival? {
        getCallCount += 1
        guard let getHandler else { throw TestError.unimplemented }
        return try getHandler(id)
    }

    private(set) var scanCallCount = 0
    private let scanHandler: (() throws -> [Festival])?
    func scan() async throws -> [Festival] {
        scanCallCount += 1
        guard let scanHandler else { throw TestError.unimplemented }
        return try scanHandler()
    }

    private(set) var putCount = 0
    private let putHandler: ((Festival) throws -> Festival)?
    func put(_ item: Festival) async throws -> Festival {
        putCount += 1
        guard let putHandler else { throw TestError.unimplemented }
        return try putHandler(item)
    }
}

// MARK: - DistrictRepositoryMock
final class DistrictRepositoryMock: DistrictRepositoryProtocol, @unchecked Sendable {
    init(
        getHandler: ((String) async throws -> District?)? = nil,
        queryHandler: ((String) async throws -> [District])? = nil,
        putHandler: ((String, District) async throws -> District)? = nil,
        postHandler: ((District) async throws -> District)? = nil
    ) {
        self.getHandler = getHandler
        self.queryHandler = queryHandler
        self.putHandler = putHandler
        self.postHandler = postHandler
    }

    private(set) var getCallCount = 0
    private let getHandler: ((String) async throws -> District?)?
    func get(id: String) async throws -> District? {
        getCallCount += 1
        guard let getHandler else { throw TestError.unimplemented }
        return try await getHandler(id)
    }

    private(set) var queryCallCount = 0
    private let queryHandler: ((String) async throws -> [District])?
    func query(by festivalId: String) async throws -> [District] {
        queryCallCount += 1
        guard let queryHandler else { throw TestError.unimplemented }
        return try await queryHandler(festivalId)
    }

    private(set) var putCallCount = 0
    private let putHandler: ((String, District) async throws -> District)?
    func put(id: String, item: District) async throws -> District {
        putCallCount += 1
        guard let putHandler else { throw TestError.unimplemented }
        return try await putHandler(id, item)
    }

    private(set) var postCallCount = 0
    private let postHandler: ((District) async throws -> District)?
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
        queryByYearHandler: ((String, Int) async throws -> [Route])? = nil,
        postHandler: ((Route) async throws -> Route)? = nil,
        putHandler: ((Route) async throws -> Route)? = nil,
        deleteHandler: ((String) async throws -> Void)? = nil
    ) {
        self.getHandler = getHandler
        self.queryHandler = queryHandler
        self.queryByYearHandler = queryByYearHandler
        self.postHandler = postHandler
        self.putHandler = putHandler
        self.deleteHandler = deleteHandler
    }

    private(set) var getCallCount = 0
    private let getHandler: ((String) async throws -> Route?)?
    func get(id: String) async throws -> Route? {
        getCallCount += 1
        guard let getHandler else { throw TestError.unimplemented }
        return try await getHandler(id)
    }

    private(set) var queryCallCount = 0
    private let queryHandler: ((String) async throws -> [Route])?
    func query(by districtId: String) async throws -> [Route] {
        queryCallCount += 1
        guard let queryHandler else { throw TestError.unimplemented }
        return try await queryHandler(districtId)
    }

    private(set) var queryByYearCallCount = 0
    private let queryByYearHandler: ((String, Int) async throws -> [Route])?
    func query(by districtId: String, year: Int) async throws -> [Route] {
        queryByYearCallCount += 1
        guard let queryByYearHandler else { throw TestError.unimplemented }
        return try await queryByYearHandler(districtId, year)
    }

    private(set) var postCallCount = 0
    private let postHandler: ((Route) async throws -> Route)?
    func post(_ route: Route) async throws -> Route {
        postCallCount += 1
        guard let postHandler else { throw TestError.unimplemented }
        return try await postHandler(route)
    }

    private(set) var putCallCount = 0
    private let putHandler: ((Route) async throws -> Route)?
    func put(_ route: Route) async throws -> Route {
        putCallCount += 1
        guard let putHandler else { throw TestError.unimplemented }
        return try await putHandler(route)
    }

    private(set) var deleteCallCount = 0
    private let deleteHandler: ((String) async throws -> Void)?
    func delete(id: String) async throws {
        deleteCallCount += 1
        guard let deleteHandler else { throw TestError.unimplemented }
        try await deleteHandler(id)
    }
}

// MARK: - LocationRepositoryMock
final class LocationRepositoryMock: LocationRepositoryProtocol, @unchecked Sendable {
    init(
        getHandler: ((String, String) async throws -> FloatLocation?)? = nil,
        queryHandler: ((String) async throws -> [FloatLocation])? = nil,
        postHandler: ((FloatLocation, Festival.ID) async throws -> FloatLocation)? = nil,
        putHandler: ((FloatLocation, Festival.ID) async throws -> FloatLocation)? = nil,
        deleteHandler: ((String, String) async throws -> Void)? = nil
    ) {
        self.getHandler = getHandler
        self.queryHandler = queryHandler
        self.postHandler = postHandler
        self.putHandler = putHandler
        self.deleteHandler = deleteHandler
    }

    private(set) var getCallCount = 0
    private let getHandler: ((String, String) async throws -> FloatLocation?)?
    func get(festivalId: String, districtId: String) async throws -> FloatLocation? {
        getCallCount += 1
        guard let getHandler else { throw TestError.unimplemented }
        return try await getHandler(festivalId, districtId)
    }

    private(set) var queryCallCount = 0
    private let queryHandler: ((String) async throws -> [FloatLocation])?
    func query(by festivalId: String) async throws -> [FloatLocation] {
        queryCallCount += 1
        guard let queryHandler else { throw TestError.unimplemented }
        return try await queryHandler(festivalId)
    }

    private(set) var postCallCount = 0
    private let postHandler: ((FloatLocation, Festival.ID) async throws -> FloatLocation)?
    func post(_ location: FloatLocation, festivalId: Festival.ID) async throws -> FloatLocation {
        postCallCount += 1
        guard let postHandler else { throw TestError.unimplemented }
        return try await postHandler(location, festivalId)
    }

    private(set) var putCallCount = 0
    private let putHandler: ((FloatLocation, Festival.ID) async throws -> FloatLocation)?
    func put(_ location: FloatLocation, festivalId: Festival.ID) async throws -> FloatLocation {
        putCallCount += 1
        guard let putHandler else { throw TestError.unimplemented }
        return try await putHandler(location, festivalId)
    }

    private(set) var deleteCallCount = 0
    private let deleteHandler: ((String, String) async throws -> Void)?
    func delete(festivalId: String, districtId: String) async throws {
        deleteCallCount += 1
        guard let deleteHandler else { throw TestError.unimplemented }
        try await deleteHandler(festivalId, districtId)
    }
}

// MARK: - PeriodRepositoryMock
final class PeriodRepositoryMock: PeriodRepositoryProtocol, @unchecked Sendable {
    init(
        getHandler: ((Period.ID) async throws -> Period?)? = nil,
        queryByYearHandler: ((String, Int) async throws -> [Period])? = nil,
        queryHandler: ((String) async throws -> [Period])? = nil,
        postHandler: ((Period) async throws -> Period)? = nil,
        putHandler: ((Period) async throws -> Period)? = nil,
        deleteHandler: ((String, SimpleDate, SimpleTime) async throws -> Void)? = nil
    ) {
        self.getHandler = getHandler
        self.queryByYearHandler = queryByYearHandler
        self.queryHandler = queryHandler
        self.postHandler = postHandler
        self.putHandler = putHandler
        self.deleteHandler = deleteHandler
    }

    private(set) var getCallCount = 0
    private let getHandler: ((Period.ID) async throws -> Period?)?
    func get(id: Period.ID) async throws -> Period? {
        getCallCount += 1
        guard let getHandler else { throw TestError.unimplemented }
        return try await getHandler(id)
    }

    private(set) var queryByYearCallCount = 0
    private let queryByYearHandler: ((String, Int) async throws -> [Period])?
    func query(by festivalId: String, year: Int) async throws -> [Period] {
        queryByYearCallCount += 1
        guard let queryByYearHandler else { throw TestError.unimplemented }
        return try await queryByYearHandler(festivalId, year)
    }

    private(set) var queryCallCount = 0
    private let queryHandler: ((String) async throws -> [Period])?
    func query(by festivalId: String) async throws -> [Period] {
        queryCallCount += 1
        guard let queryHandler else { throw TestError.unimplemented }
        return try await queryHandler(festivalId)
    }

    private(set) var postCallCount = 0
    private let postHandler: ((Period) async throws -> Period)?
    func post(_ period: Period) async throws -> Period {
        postCallCount += 1
        guard let postHandler else { throw TestError.unimplemented }
        return try await postHandler(period)
    }

    private(set) var putCallCount = 0
    private let putHandler: ((Period) async throws -> Period)?
    func put(_ period: Period) async throws -> Period {
        putCallCount += 1
        guard let putHandler else { throw TestError.unimplemented }
        return try await putHandler(period)
    }

    private(set) var deleteCallCount = 0
    private let deleteHandler: ((String, SimpleDate, SimpleTime) async throws -> Void)?
    func delete(festivalId: String, date: SimpleDate, start: SimpleTime) async throws {
        deleteCallCount += 1
        guard let deleteHandler else { throw TestError.unimplemented }
        try await deleteHandler(festivalId, date, start)
    }
}

// MARK: - PointRepositoryMock
final class PointRepositoryMock: PointRepositoryProtocol, @unchecked Sendable {
    init(
        getHandler: ((Point.ID) async throws -> Point?)? = nil,
        queryHandler: ((String) async throws -> [Point])? = nil,
        postHandler: ((Point) async throws -> Point)? = nil,
        putHandler: ((Point) async throws -> Point)? = nil,
        deleteItemHandler: ((Point) async throws -> Void)? = nil,
        deleteByRouteHandler: ((Route.ID) async throws -> Void)? = nil
    ) {
        self.getHandler = getHandler
        self.queryHandler = queryHandler
        self.postHandler = postHandler
        self.putHandler = putHandler
        self.deleteItemHandler = deleteItemHandler
        self.deleteByRouteHandler = deleteByRouteHandler
    }

    private(set) var getCallCount = 0
    private let getHandler: ((Point.ID) async throws -> Point?)?
    func get(id: Point.ID) async throws -> Point? {
        getCallCount += 1
        guard let getHandler else { throw TestError.unimplemented }
        return try await getHandler(id)
    }

    private(set) var queryCallCount = 0
    private let queryHandler: ((String) async throws -> [Point])?
    func query(by routeId: String) async throws -> [Point] {
        queryCallCount += 1
        guard let queryHandler else { throw TestError.unimplemented }
        return try await queryHandler(routeId)
    }

    private(set) var putCallCount = 0
    private let putHandler: ((Point) async throws -> Point)?
    func put(_ item: Point) async throws -> Point {
        putCallCount += 1
        guard let putHandler else { throw TestError.unimplemented }
        return try await putHandler(item)
    }

    private(set) var postCallCount = 0
    private let postHandler: ((Point) async throws -> Point)?
    func post(_ item: Point) async throws -> Point {
        postCallCount += 1
        guard let postHandler else { throw TestError.unimplemented }
        return try await postHandler(item)
    }

    private(set) var deleteItemCallCount = 0
    private let deleteItemHandler: ((Point) async throws -> Void)?
    func delete(_ item: Point) async throws {
        deleteItemCallCount += 1
        guard let deleteItemHandler else { throw TestError.unimplemented }
        try await deleteItemHandler(item)
    }

    private(set) var deleteByRouteCallCount = 0
    private let deleteByRouteHandler: ((Route.ID) async throws -> Void)?
    func delete(by routeId: Route.ID) async throws {
        deleteByRouteCallCount += 1
        guard let deleteByRouteHandler else { throw TestError.unimplemented }
        try await deleteByRouteHandler(routeId)
    }
}

// MARK: - PassageRepositoryMock
final class PassageRepositoryMock: PassageRepositoryProtocol, @unchecked Sendable {
    init(
        getHandler: ((RoutePassage.ID) async throws -> RoutePassage?)? = nil,
        queryHandler: ((String) async throws -> [RoutePassage])? = nil,
        postHandler: ((RoutePassage) async throws -> RoutePassage)? = nil,
        putHandler: ((RoutePassage) async throws -> RoutePassage)? = nil,
        deleteItemHandler: ((RoutePassage) async throws -> Void)? = nil,
        deleteByRouteHandler: ((Route.ID) async throws -> Void)? = nil
    ) {
        self.getHandler = getHandler
        self.queryHandler = queryHandler
        self.postHandler = postHandler
        self.putHandler = putHandler
        self.deleteItemHandler = deleteItemHandler
        self.deleteByRouteHandler = deleteByRouteHandler
    }

    private(set) var getCallCount = 0
    private let getHandler: ((RoutePassage.ID) async throws -> RoutePassage?)?
    func get(id: RoutePassage.ID) async throws -> RoutePassage? {
        getCallCount += 1
        guard let getHandler else { throw TestError.unimplemented }
        return try await getHandler(id)
    }

    private(set) var queryCallCount = 0
    private let queryHandler: ((String) async throws -> [RoutePassage])?
    func query(by routeId: String) async throws -> [RoutePassage] {
        queryCallCount += 1
        guard let queryHandler else { throw TestError.unimplemented }
        return try await queryHandler(routeId)
    }

    private(set) var putCallCount = 0
    private let putHandler: ((RoutePassage) async throws -> RoutePassage)?
    func put(_ item: RoutePassage) async throws -> RoutePassage {
        putCallCount += 1
        guard let putHandler else { throw TestError.unimplemented }
        return try await putHandler(item)
    }

    private(set) var postCallCount = 0
    private let postHandler: ((RoutePassage) async throws -> RoutePassage)?
    func post(_ item: RoutePassage) async throws -> RoutePassage {
        postCallCount += 1
        guard let postHandler else { throw TestError.unimplemented }
        return try await postHandler(item)
    }

    private(set) var deleteItemCallCount = 0
    private let deleteItemHandler: ((RoutePassage) async throws -> Void)?
    func delete(_ item: RoutePassage) async throws {
        deleteItemCallCount += 1
        guard let deleteItemHandler else { throw TestError.unimplemented }
        try await deleteItemHandler(item)
    }

    private(set) var deleteByRouteCallCount = 0
    private let deleteByRouteHandler: ((Route.ID) async throws -> Void)?
    func delete(by routeId: Route.ID) async throws {
        deleteByRouteCallCount += 1
        guard let deleteByRouteHandler else { throw TestError.unimplemented }
        try await deleteByRouteHandler(routeId)
    }
}

// MARK: - CheckpointRepositoryMock
final class CheckpointRepositoryMock: CheckpointRepositoryProtocol, @unchecked Sendable {
    init(
        getHandler: ((String) async throws -> Checkpoint?)? = nil,
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

    private(set) var getCallCount = 0
    private let getHandler: ((String) async throws -> Checkpoint?)?
    func get(id: String) async throws -> Checkpoint? {
        getCallCount += 1
        guard let getHandler else { throw TestError.unimplemented }
        return try await getHandler(id)
    }

    private(set) var queryCallCount = 0
    private let queryHandler: ((Festival.ID) async throws -> [Checkpoint])?
    func query(by festivalId: Festival.ID) async throws -> [Checkpoint] {
        queryCallCount += 1
        guard let queryHandler else { throw TestError.unimplemented }
        return try await queryHandler(festivalId)
    }

    private(set) var postCallCount = 0
    private let postHandler: ((Checkpoint) async throws -> Checkpoint)?
    func post(_ item: Checkpoint) async throws -> Checkpoint {
        postCallCount += 1
        guard let postHandler else { throw TestError.unimplemented }
        return try await postHandler(item)
    }

    private(set) var putCallCount = 0
    private let putHandler: ((Checkpoint) async throws -> Checkpoint)?
    func put(_ item: Checkpoint) async throws -> Checkpoint {
        putCallCount += 1
        guard let putHandler else { throw TestError.unimplemented }
        return try await putHandler(item)
    }

    private(set) var deleteCallCount = 0
    private let deleteHandler: ((Checkpoint) async throws -> Void)?
    func delete(_ item: Checkpoint) async throws {
        deleteCallCount += 1
        guard let deleteHandler else { throw TestError.unimplemented }
        try await deleteHandler(item)
    }
}

// MARK: - HazardSectionRepositoryMock
final class HazardSectionRepositoryMock: HazardSectionRepositoryProtocol, @unchecked Sendable {
    init(
        getHandler: ((String) async throws -> HazardSection?)? = nil,
        queryHandler: ((String) async throws -> [HazardSection])? = nil,
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

    private(set) var getCallCount = 0
    private let getHandler: ((String) async throws -> HazardSection?)?
    func get(id: String) async throws -> HazardSection? {
        getCallCount += 1
        guard let getHandler else { throw TestError.unimplemented }
        return try await getHandler(id)
    }

    private(set) var queryCallCount = 0
    private let queryHandler: ((String) async throws -> [HazardSection])?
    func query(by festivalId: String) async throws -> [HazardSection] {
        queryCallCount += 1
        guard let queryHandler else { throw TestError.unimplemented }
        return try await queryHandler(festivalId)
    }

    private(set) var postCallCount = 0
    private let postHandler: ((HazardSection) async throws -> HazardSection)?
    func post(_ item: HazardSection) async throws -> HazardSection {
        postCallCount += 1
        guard let postHandler else { throw TestError.unimplemented }
        return try await postHandler(item)
    }

    private(set) var putCallCount = 0
    private let putHandler: ((HazardSection) async throws -> HazardSection)?
    func put(_ item: HazardSection) async throws -> HazardSection {
        putCallCount += 1
        guard let putHandler else { throw TestError.unimplemented }
        return try await putHandler(item)
    }

    private(set) var deleteCallCount = 0
    private let deleteHandler: ((HazardSection) async throws -> Void)?
    func delete(_ item: HazardSection) async throws {
        deleteCallCount += 1
        guard let deleteHandler else { throw TestError.unimplemented }
        try await deleteHandler(item)
    }
}

// MARK: - PerformanceRepositoryMock
final class PerformanceRepositoryMock: PerformanceRepositoryProtocol, @unchecked Sendable {
    init(
        getHandler: ((String) async throws -> Performance?)? = nil,
        queryHandler: ((String) async throws -> [Performance])? = nil,
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

    private(set) var getCallCount = 0
    private let getHandler: ((String) async throws -> Performance?)?
    func get(id: String) async throws -> Performance? {
        getCallCount += 1
        guard let getHandler else { throw TestError.unimplemented }
        return try await getHandler(id)
    }

    private(set) var queryCallCount = 0
    private let queryHandler: ((String) async throws -> [Performance])?
    func query(by festivalId: String) async throws -> [Performance] {
        queryCallCount += 1
        guard let queryHandler else { throw TestError.unimplemented }
        return try await queryHandler(festivalId)
    }

    private(set) var postCallCount = 0
    private let postHandler: ((Performance) async throws -> Performance)?
    func post(_ item: Performance) async throws -> Performance {
        postCallCount += 1
        guard let postHandler else { throw TestError.unimplemented }
        return try await postHandler(item)
    }

    private(set) var putCallCount = 0
    private let putHandler: ((Performance) async throws -> Performance)?
    func put(_ item: Performance) async throws -> Performance {
        putCallCount += 1
        guard let putHandler else { throw TestError.unimplemented }
        return try await putHandler(item)
    }

    private(set) var deleteCallCount = 0
    private let deleteHandler: ((Performance) async throws -> Void)?
    func delete(_ item: Performance) async throws {
        deleteCallCount += 1
        guard let deleteHandler else { throw TestError.unimplemented }
        try await deleteHandler(item)
    }
}
