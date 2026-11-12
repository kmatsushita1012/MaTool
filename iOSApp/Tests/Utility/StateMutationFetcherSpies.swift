import Foundation
import Shared
@testable import iOSApp

enum FetcherTestError: Swift.Error, Equatable {
    case failed
}

actor PeriodDataFetcherSpy: PeriodDataFetcherProtocol {
    let response: Period
    let list: [Period]
    let shouldFail: Bool
    private var operations: [String] = []

    init(response: Period, list: [Period] = [], shouldFail: Bool = false) {
        self.response = response
        self.list = list
        self.shouldFail = shouldFail
    }

    func recordedCalls() -> [String] { operations }

    func fetchAll(festivalID: Festival.ID, query: Query) async throws -> [Period] {
        operations.append("fetchAll:\(festivalID):\(String(describing: query))")
        if shouldFail { throw FetcherTestError.failed }
        return list
    }

    func fetch(_ id: Period.ID) async throws -> Period {
        operations.append("fetch:\(id)")
        if shouldFail { throw FetcherTestError.failed }
        return response
    }

    func update(_ period: Period) async throws -> Period {
        operations.append("update:\(period.id)")
        if shouldFail { throw FetcherTestError.failed }
        return response
    }

    func create(_ period: Period) async throws -> Period {
        operations.append("create:\(period.id)")
        if shouldFail { throw FetcherTestError.failed }
        return response
    }

    func delete(_ id: Period.ID) async throws {
        operations.append("delete:\(id)")
        if shouldFail { throw FetcherTestError.failed }
    }
}

actor RouteDataFetcherSpy: RouteDataFetcherProtocol {
    let pack: RoutePack
    let routes: [Route]
    let shouldFail: Bool
    private var operations: [String] = []

    init(pack: RoutePack, routes: [Route] = [], shouldFail: Bool = false) {
        self.pack = pack
        self.routes = routes
        self.shouldFail = shouldFail
    }

    func recordedCalls() -> [String] { operations }

    func fetchAll(districtID: District.ID, query: Query) async throws -> [Route] {
        operations.append("fetchAll:\(districtID):\(String(describing: query))")
        if shouldFail { throw FetcherTestError.failed }
        return routes
    }

    func fetch(routeID: Route.ID) async throws -> RoutePack {
        operations.append("fetch:\(routeID)")
        if shouldFail { throw FetcherTestError.failed }
        return pack
    }

    func update(_ route: Route, points: [Point], passages: [RoutePassage]) async throws -> RoutePack {
        operations.append("update:\(route.id)")
        if shouldFail { throw FetcherTestError.failed }
        return pack
    }

    func create(districtID: District.ID, route: Route, points: [Point], passages: [RoutePassage]) async throws -> RoutePack {
        operations.append("create:\(districtID):\(route.id)")
        if shouldFail { throw FetcherTestError.failed }
        return pack
    }

    func delete(_ routeID: Route.ID) async throws {
        operations.append("delete:\(routeID)")
        if shouldFail { throw FetcherTestError.failed }
    }
}

actor LocationDataFetcherSpy: LocationDataFetcherProtocol {
    let response: FloatLocation
    let list: [FloatLocation]
    let shouldFail: Bool
    private var operations: [String] = []

    init(response: FloatLocation, list: [FloatLocation] = [], shouldFail: Bool = false) {
        self.response = response
        self.list = list
        self.shouldFail = shouldFail
    }

    func recordedCalls() -> [String] { operations }

    func fetchAll(festivalId: Festival.ID) async throws -> [FloatLocation] {
        operations.append("fetchAll:\(festivalId)")
        if shouldFail { throw FetcherTestError.failed }
        return list
    }

    func fetch(districtId: District.ID) async throws -> FloatLocation? {
        operations.append("fetch:\(districtId)")
        if shouldFail { throw FetcherTestError.failed }
        return response
    }

    func update(_ location: FloatLocation) async throws -> FloatLocation {
        operations.append("update:\(location.id)")
        if shouldFail { throw FetcherTestError.failed }
        return response
    }

    func delete(districtId: District.ID) async throws {
        operations.append("delete:\(districtId)")
        if shouldFail { throw FetcherTestError.failed }
    }
}
