import Dependencies
import Foundation
import SQLiteData
import Shared
import Testing
@testable import iOSApp

@Suite(.serialized)
struct RoutePeriodChildDeletionTests {
    @Test
    func routeDeleteRemovesPointsAndPassagesWithoutTouchingOtherRoutes() async throws {
        let database = try makeTestDatabase()
        let deletedRoute = Route(id: "route-delete", districtId: "district-1", periodId: "period-1")
        let retainedRoute = Route(id: "route-retain", districtId: "district-1", periodId: "period-1")
        let deletedPoint = point(id: "point-delete", routeId: deletedRoute.id)
        let retainedPoint = point(id: "point-retain", routeId: retainedRoute.id)
        let deletedPassage = RoutePassage(id: "passage-delete", routeId: deletedRoute.id)
        let retainedPassage = RoutePassage(id: "passage-retain", routeId: retainedRoute.id)
        try await seed(
            routes: [deletedRoute, retainedRoute],
            points: [deletedPoint, retainedPoint],
            passages: [deletedPassage, retainedPassage],
            into: database
        )
        let recorder = DeleteRequestRecorder()
        let client = try TestHTTPClient(response: [Period](), recorder: recorder)

        try await withDependencies {
            $0.defaultDatabase = database
            $0.httpClient = client
            $0.authService = TestAuthService()
            $0[RouteStoreKey.self] = SQLiteStore<Route>()
            $0[PointStoreKey.self] = SQLiteStore<Point>()
            $0[PassageStoreKey.self] = SQLiteStore<RoutePassage>()
        } operation: {
            try await RouteDataFetcher().delete(deletedRoute.id)
        }

        let stored = try await fetchRouteRows(from: database)
        #expect(Set(stored.routes.map(\.id)) == Set([retainedRoute.id]))
        #expect(Set(stored.points.map(\.id)) == Set([retainedPoint.id]))
        #expect(Set(stored.passages.map(\.id)) == Set([retainedPassage.id]))
        #expect(await recorder.paths() == ["/routes/route-delete"])
    }

    @Test
    func periodDeleteRemovesAllRouteChildrenAndRetainsOtherPeriods() async throws {
        let database = try makeTestDatabase()
        let deletedRoute = Route(id: "route-delete", districtId: "district-1", periodId: "period-delete")
        let retainedRoute = Route(id: "route-retain", districtId: "district-1", periodId: "period-retain")
        let deletedPoint = point(id: "point-delete", routeId: deletedRoute.id)
        let retainedPoint = point(id: "point-retain", routeId: retainedRoute.id)
        let deletedPassage = RoutePassage(id: "passage-delete", routeId: deletedRoute.id)
        let retainedPassage = RoutePassage(id: "passage-retain", routeId: retainedRoute.id)
        let deletedPeriod = period("period-delete")
        let retainedPeriod = period("period-retain")
        try await seed(
            periods: [deletedPeriod, retainedPeriod],
            routes: [deletedRoute, retainedRoute],
            points: [deletedPoint, retainedPoint],
            passages: [deletedPassage, retainedPassage],
            into: database
        )
        let recorder = DeleteRequestRecorder()
        let client = try TestHTTPClient(response: [Period](), recorder: recorder)

        try await withDependencies {
            $0.defaultDatabase = database
            $0.httpClient = client
            $0.authService = TestAuthService()
            $0[PeriodStoreKey.self] = SQLiteStore<Period>()
            $0[RouteStoreKey.self] = SQLiteStore<Route>()
            $0[PointStoreKey.self] = SQLiteStore<Point>()
            $0[PassageStoreKey.self] = SQLiteStore<RoutePassage>()
        } operation: {
            try await PeriodDataFetcher().delete(deletedPeriod.id)
        }

        let stored = try await fetchPeriodRows(from: database)
        #expect(Set(stored.periods.map(\.id)) == Set([retainedPeriod.id]))
        #expect(Set(stored.routes.map(\.id)) == Set([retainedRoute.id]))
        #expect(Set(stored.points.map(\.id)) == Set([retainedPoint.id]))
        #expect(Set(stored.passages.map(\.id)) == Set([retainedPassage.id]))
        #expect(await recorder.paths() == ["/periods/period-delete"])
    }

    @Test
    func periodRefreshRemovesChildrenOfPeriodsNoLongerReturnedByServer() async throws {
        let database = try makeTestDatabase()
        let deletedPeriod = period("period-delete")
        let retainedPeriod = period("period-retain")
        let deletedRoute = Route(id: "route-delete", districtId: "district-1", periodId: deletedPeriod.id)
        let retainedRoute = Route(id: "route-retain", districtId: "district-1", periodId: retainedPeriod.id)
        let deletedPoint = point(id: "point-delete", routeId: deletedRoute.id)
        let retainedPoint = point(id: "point-retain", routeId: retainedRoute.id)
        let deletedPassage = RoutePassage(id: "passage-delete", routeId: deletedRoute.id)
        let retainedPassage = RoutePassage(id: "passage-retain", routeId: retainedRoute.id)
        try await seed(
            periods: [deletedPeriod, retainedPeriod],
            routes: [deletedRoute, retainedRoute],
            points: [deletedPoint, retainedPoint],
            passages: [deletedPassage, retainedPassage],
            into: database
        )
        let recorder = DeleteRequestRecorder()
        let client = try TestHTTPClient(response: [retainedPeriod], recorder: recorder)

        try await withDependencies {
            $0.defaultDatabase = database
            $0.httpClient = client
            $0[PeriodStoreKey.self] = SQLiteStore<Period>()
            $0[RouteStoreKey.self] = SQLiteStore<Route>()
            $0[PointStoreKey.self] = SQLiteStore<Point>()
            $0[PassageStoreKey.self] = SQLiteStore<RoutePassage>()
        } operation: {
            try await PeriodDataFetcher().fetchAll(festivalID: retainedPeriod.festivalId, query: .all)
        }

        let stored = try await fetchPeriodRows(from: database)
        #expect(Set(stored.periods.map(\.id)) == Set([retainedPeriod.id]))
        #expect(Set(stored.routes.map(\.id)) == Set([retainedRoute.id]))
        #expect(Set(stored.points.map(\.id)) == Set([retainedPoint.id]))
        #expect(Set(stored.passages.map(\.id)) == Set([retainedPassage.id]))
        #expect(await recorder.paths().isEmpty)
    }
}

private func makeTestDatabase() throws -> DatabaseQueue {
    let database = try DatabaseQueue(path: ":memory:")
    try makeDatabaseMigrator().migrate(database)
    return database
}

private func seed(
    periods: [Period] = [],
    routes: [Route],
    points: [Point],
    passages: [RoutePassage],
    into database: DatabaseQueue
) async throws {
    try await database.write { db in
        try SQLiteStore<Period>().upsert(periods, at: db)
        try SQLiteStore<Route>().upsert(routes, at: db)
        try SQLiteStore<Point>().upsert(points, at: db)
        try SQLiteStore<RoutePassage>().upsert(passages, at: db)
    }
}

private func fetchRouteRows(from database: DatabaseQueue) async throws -> (
    routes: [Route],
    points: [Point],
    passages: [RoutePassage]
) {
    try await database.read { db in
        (
            routes: try SQLiteStore<Route>().fetchAll(from: db),
            points: try SQLiteStore<Point>().fetchAll(from: db),
            passages: try SQLiteStore<RoutePassage>().fetchAll(from: db)
        )
    }
}

private func fetchPeriodRows(from database: DatabaseQueue) async throws -> (
    periods: [Period],
    routes: [Route],
    points: [Point],
    passages: [RoutePassage]
) {
    try await database.read { db in
        (
            periods: try SQLiteStore<Period>().fetchAll(from: db),
            routes: try SQLiteStore<Route>().fetchAll(from: db),
            points: try SQLiteStore<Point>().fetchAll(from: db),
            passages: try SQLiteStore<RoutePassage>().fetchAll(from: db)
        )
    }
}

private func period(_ id: String) -> Period {
    Period(
        id: id,
        festivalId: "festival-1",
        title: id,
        date: SimpleDate(year: 2026, month: 10, day: 3),
        start: SimpleTime(hour: 10, minute: 0),
        end: SimpleTime(hour: 11, minute: 0)
    )
}

private func point(id: String, routeId: Route.ID) -> Point {
    Point(
        id: id,
        routeId: routeId,
        coordinate: Coordinate(latitude: 34.77, longitude: 138.01)
    )
}

private actor DeleteRequestRecorder {
    private var recordedPaths: [String] = []

    func record(_ path: String) {
        recordedPaths.append(path)
    }

    func paths() -> [String] {
        recordedPaths
    }
}

private enum DataFetcherTestError: Error {
    case unexpectedRequest
    case deleteFailed
}

private struct TestHTTPClient: HTTPClientProtocol {
    let responseData: Data
    let recorder: DeleteRequestRecorder
    let deleteShouldFail: Bool

    init<Response: Encodable>(response: Response, recorder: DeleteRequestRecorder, deleteShouldFail: Bool = false) throws {
        self.responseData = try JSONEncoder().encode(response)
        self.recorder = recorder
        self.deleteShouldFail = deleteShouldFail
    }

    func request<Response: Decodable, Body: Encodable>(
        path: String,
        method: String,
        query: [String: Any],
        body: Body?,
        accessToken: String?,
        isCache: Bool
    ) async throws -> Response {
        try decodeResponse()
    }

    func request<Response: Decodable>(
        path: String,
        method: String,
        query: [String: Any],
        accessToken: String?,
        isCache: Bool
    ) async throws -> Response {
        try decodeResponse()
    }

    func get<Response: Decodable>(path: String, query: [String: Any], accessToken: String?, isCache: Bool) async throws -> Response {
        try decodeResponse()
    }

    func post<Response: Decodable, Body: Encodable>(path: String, body: Body, query: [String: Any], accessToken: String?) async throws -> Response {
        try decodeResponse()
    }

    func put<Response: Decodable, Body: Encodable>(path: String, body: Body, query: [String: Any], accessToken: String?) async throws -> Response {
        try decodeResponse()
    }

    func delete<Response: Decodable>(path: String, query: [String: Any], accessToken: String?) async throws -> Response {
        try decodeResponse()
    }

    func delete(path: String, query: [String: Any], accessToken: String?) async throws {
        await recorder.record(path)
        if deleteShouldFail {
            throw DataFetcherTestError.deleteFailed
        }
    }

    private func decodeResponse<Response: Decodable>() throws -> Response {
        try JSONDecoder().decode(Response.self, from: responseData)
    }
}

private struct TestAuthService: AuthServiceProtocol {
    func initialize() throws {}
    func signIn(_ username: String, password: String) async throws -> SignInState { throw DataFetcherTestError.unexpectedRequest }
    func confirmSignIn(password: String) async throws -> UserRole { throw DataFetcherTestError.unexpectedRequest }
    func signOut() async throws -> UserRole { .guest }
    func getAccessToken() async -> String? { "test-token" }
    func changePassword(current: String, new: String) async throws { throw DataFetcherTestError.unexpectedRequest }
    func resetPassword(username: String) async throws { throw DataFetcherTestError.unexpectedRequest }
    func confirmResetPassword(username: String, newPassword: String, code: String) async throws { throw DataFetcherTestError.unexpectedRequest }
    func updateEmail(to newEmail: String) async throws -> UpdateEmailState { throw DataFetcherTestError.unexpectedRequest }
    func confirmUpdateEmail(code: String) async throws { throw DataFetcherTestError.unexpectedRequest }
    func isValidPassword(_ password: String) -> Bool { false }
    func getUserRole() async throws -> UserRole { throw DataFetcherTestError.unexpectedRequest }
}
