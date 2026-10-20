import Dependencies
import SQLiteData
import Shared
import Testing
@testable import iOSApp

struct RouteDataFetcherYearSyncTests {
    @Test("年度指定のRoute取得では他年度のキャッシュを保持する")
    func 年度指定の取得は対象年度だけ同期する() async throws {
        let database = try makeDatabase()
        let periods = [
            makePeriod(id: "period-2024", year: 2024),
            makePeriod(id: "period-2025", year: 2025),
            makePeriod(id: "period-2026", year: 2026)
        ]
        let oldRoutes = [
            makeRoute(id: "route-2024", periodId: "period-2024"),
            makeRoute(id: "old-route-2025", periodId: "period-2025"),
            makeRoute(id: "route-2026", periodId: "period-2026")
        ]
        let refreshedRoute = makeRoute(id: "new-route-2025", periodId: "period-2025")
        try await seed(database, periods: periods, routes: oldRoutes)

        try await fetchRoutes(
            [refreshedRoute],
            districtId: "district-a",
            query: .year(2025),
            database: database
        )

        let savedRoutes = try await readRoutes(database)
        #expect(Set(savedRoutes.map(\.id)) == ["route-2024", "new-route-2025", "route-2026"])
    }

    @Test("最新年度のRoute取得では過年度のキャッシュを保持する")
    func latestの取得は最新年度だけ同期する() async throws {
        let database = try makeDatabase()
        let periods = [
            makePeriod(id: "period-2024", year: 2024),
            makePeriod(id: "period-2025", year: 2025),
            makePeriod(id: "period-2026", year: 2026)
        ]
        let oldRoutes = [
            makeRoute(id: "route-2024", periodId: "period-2024"),
            makeRoute(id: "route-2025", periodId: "period-2025"),
            makeRoute(id: "old-route-2026", periodId: "period-2026")
        ]
        let refreshedRoute = makeRoute(id: "new-route-2026", periodId: "period-2026")
        try await seed(database, periods: periods, routes: oldRoutes)

        try await fetchRoutes(
            [refreshedRoute],
            districtId: "district-a",
            query: .latest,
            database: database
        )

        let savedRoutes = try await readRoutes(database)
        #expect(Set(savedRoutes.map(\.id)) == ["route-2024", "route-2025", "new-route-2026"])
    }

    @Test("最新応答のPeriodが未キャッシュなら既存Routeを削除しない")
    func 未キャッシュのlatest年度は既存Routeを保持する() async throws {
        let database = try makeDatabase()
        let periods = [
            makePeriod(id: "period-2024", year: 2024),
            makePeriod(id: "period-2025", year: 2025)
        ]
        let oldRoutes = [
            makeRoute(id: "route-2024", periodId: "period-2024"),
            makeRoute(id: "route-2025", periodId: "period-2025")
        ]
        let returnedRoute = makeRoute(id: "route-2026", periodId: "period-2026")
        try await seed(database, periods: periods, routes: oldRoutes)

        try await fetchRoutes(
            [returnedRoute],
            districtId: "district-a",
            query: .latest,
            database: database
        )

        let savedRoutes = try await readRoutes(database)
        #expect(Set(savedRoutes.map(\.id)) == ["route-2024", "route-2025", "route-2026"])
    }

    private func makeDatabase() throws -> DatabaseQueue {
        let database = try DatabaseQueue(path: ":memory:")
        try database.write { db in
            try #sql("""
                CREATE TABLE districts (
                    id TEXT PRIMARY KEY NOT NULL,
                    name TEXT NOT NULL,
                    festivalId TEXT NOT NULL,
                    "order" INTEGER NOT NULL DEFAULT 0,
                    "group" TEXT,
                    description TEXT,
                    base TEXT,
                    area TEXT NOT NULL,
                    image TEXT NOT NULL,
                    visibility INTEGER NOT NULL DEFAULT 0,
                    isEditable INTEGER NOT NULL DEFAULT 1
                )
                """).execute(db)
            try #sql("""
                CREATE TABLE periods (
                    id TEXT PRIMARY KEY NOT NULL,
                    festivalId TEXT NOT NULL,
                    date TEXT NOT NULL,
                    title TEXT NOT NULL,
                    start TEXT NOT NULL,
                    end TEXT NOT NULL
                )
                """).execute(db)
            try #sql("""
                CREATE TABLE routes (
                    id TEXT PRIMARY KEY NOT NULL,
                    districtId TEXT NOT NULL,
                    periodId TEXT NOT NULL,
                    visibility INTEGER NOT NULL DEFAULT 0,
                    description TEXT
                )
                """).execute(db)
        }
        return database
    }

    private func seed(_ database: DatabaseQueue, periods: [Period], routes: [Route]) async throws {
        try await database.write { db in
            try SQLiteStore<District>().upsert(makeDistrict(), at: db)
            try SQLiteStore<Period>().upsert(periods, at: db)
            try SQLiteStore<Route>().upsert(routes, at: db)
        }
    }

    private func fetchRoutes(
        _ response: [Route],
        districtId: District.ID,
        query: Query,
        database: DatabaseQueue
    ) async throws {
        let httpClient = RouteResponseHTTPClient(routes: response)
        try await withDependencies {
            $0.defaultDatabase = database
            $0.httpClient = httpClient
            $0.authService = RouteSyncAuthService()
            $0[RouteStoreKey.self] = SQLiteStore<Route>()
            $0[DistrictStoreKey.self] = SQLiteStore<District>()
            $0[PeriodStoreKey.self] = SQLiteStore<Period>()
        } operation: {
            try await RouteDataFetcher().fetchAll(districtID: districtId, query: query)
        }
    }

    private func readRoutes(_ database: DatabaseQueue) async throws -> [Route] {
        try await database.read { db in
            try SQLiteStore<Route>().fetchAll(from: db)
        }
    }

    private func makeDistrict() -> District {
        District(id: "district-a", name: "District A", festivalId: "festival-a")
    }

    private func makePeriod(id: Period.ID, year: Int) -> Period {
        Period(
            id: id,
            festivalId: "festival-a",
            title: "Period \(year)",
            date: SimpleDate(year: year, month: 5, day: 1),
            start: SimpleTime(hour: 9, minute: 0),
            end: SimpleTime(hour: 17, minute: 0)
        )
    }

    private func makeRoute(id: Route.ID, periodId: Period.ID) -> Route {
        Route(id: id, districtId: "district-a", periodId: periodId)
    }
}

private actor RouteResponseHTTPClient: HTTPClientProtocol {
    private let routes: [Route]

    init(routes: [Route]) {
        self.routes = routes
    }

    func get<Response: Decodable>(
        path: String,
        query: [String: Any],
        accessToken: String?,
        isCache: Bool
    ) async throws -> Response {
        guard let response = routes as? Response else { throw RouteSyncTestError.unexpectedResponse }
        return response
    }

    func request<Response: Decodable, Body: Encodable>(
        path: String,
        method: String,
        query: [String: Any],
        body: Body?,
        accessToken: String?,
        isCache: Bool
    ) async throws -> Response {
        throw RouteSyncTestError.unexpectedRequest
    }

    func request<Response: Decodable>(
        path: String,
        method: String,
        query: [String: Any],
        accessToken: String?,
        isCache: Bool
    ) async throws -> Response {
        throw RouteSyncTestError.unexpectedRequest
    }

    func post<Response: Decodable, Body: Encodable>(
        path: String,
        body: Body,
        query: [String: Any],
        accessToken: String?
    ) async throws -> Response {
        throw RouteSyncTestError.unexpectedRequest
    }

    func put<Response: Decodable, Body: Encodable>(
        path: String,
        body: Body,
        query: [String: Any],
        accessToken: String?
    ) async throws -> Response {
        throw RouteSyncTestError.unexpectedRequest
    }

    func delete<Response: Decodable>(
        path: String,
        query: [String: Any],
        accessToken: String?
    ) async throws -> Response {
        throw RouteSyncTestError.unexpectedRequest
    }

    func delete(path: String, query: [String: Any], accessToken: String?) async throws {
        throw RouteSyncTestError.unexpectedRequest
    }
}

private struct RouteSyncAuthService: AuthServiceProtocol {
    func initialize() throws {}
    func signIn(_ username: String, password: String) async throws -> SignInState { .signedIn(.guest) }
    func confirmSignIn(password: String) async throws -> UserRole { .guest }
    func signOut() async throws -> UserRole { .guest }
    func getAccessToken() async -> String? { nil }
    func changePassword(current: String, new: String) async throws {}
    func resetPassword(username: String) async throws {}
    func confirmResetPassword(username: String, newPassword: String, code: String) async throws {}
    func updateEmail(to newEmail: String) async throws -> UpdateEmailState { .completed }
    func confirmUpdateEmail(code: String) async throws {}
    func isValidPassword(_ password: String) -> Bool { true }
    func getUserRole() async throws -> UserRole { .guest }
}

private enum RouteSyncTestError: Error {
    case unexpectedRequest
    case unexpectedResponse
}
