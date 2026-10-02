import Dependencies
import SQLiteData
import Shared
import Testing
@testable import iOSApp

struct SceneLaunchCacheTests {
    @Test("起動時の通信失敗後も保存済みの祭典と町を表示できる")
    func startupFailureUsesPersistedSelection() async throws {
        let database = try await makeDatabaseWithCachedSelection()
        let userDefaults = LaunchCacheUserDefaults(
            defaultFestivalId: "festival-a",
            defaultDistrictId: "district-a"
        )

        let launchState = await withDependencies {
            $0.defaultDatabase = database
            $0[HTTPClientKey.self] = HTTPClient(base: "http://127.0.0.1:1")
            $0[AuthServiceKey.self] = LaunchCacheAuthService()
            $0[AppStatusClientKey.self] = LaunchCacheAppStatusClient()
            $0[SceneDataFetcherKey.self] = SceneDataFetcher()
            $0[FestivalStoreKey.self] = SQLiteStore<Festival>()
            $0[DistrictStoreKey.self] = SQLiteStore<District>()
        } operation: {
            await SceneUsecase(userDefaults: userDefaults).launch().0
        }

        switch launchState {
        case .district(.guest, nil):
            break
        default:
            Issue.record("通信失敗時も保存済み町のホーム状態になる想定でした: \(launchState)")
        }

        let cachedIDs = try await database.read { db in
            (
                try FestivalStoreKey.liveValue.fetchAll(from: db).map(\.id),
                try DistrictStoreKey.liveValue.fetchAll(from: db).map(\.id)
            )
        }
        #expect(cachedIDs.0 == ["festival-a"])
        #expect(cachedIDs.1 == ["district-a"])
    }
}

private func makeDatabaseWithCachedSelection() async throws -> DatabaseQueue {
    let database = try DatabaseQueue(path: ":memory:")
    try await database.write { db in
        try db.execute(sql: """
            CREATE TABLE festivals (
                id TEXT PRIMARY KEY NOT NULL, name TEXT NOT NULL, subname TEXT NOT NULL,
                description TEXT, prefecture TEXT NOT NULL, city TEXT NOT NULL,
                base TEXT NOT NULL, image TEXT NOT NULL
            )
            """)
        try db.execute(sql: """
            CREATE TABLE checkpoints (
                id TEXT PRIMARY KEY NOT NULL, festivalId TEXT NOT NULL,
                name TEXT NOT NULL, description TEXT
            )
            """)
        try db.execute(sql: """
            CREATE TABLE hazardsections (
                id TEXT PRIMARY KEY NOT NULL, title TEXT NOT NULL,
                festivalId TEXT NOT NULL, coordinates TEXT NOT NULL
            )
            """)
        try db.execute(sql: """
            CREATE TABLE periods (
                id TEXT PRIMARY KEY NOT NULL, festivalId TEXT NOT NULL,
                date TEXT NOT NULL, title TEXT NOT NULL, start TEXT NOT NULL, end TEXT NOT NULL
            )
            """)
        try db.execute(sql: """
            CREATE TABLE districts (
                id TEXT PRIMARY KEY NOT NULL, name TEXT NOT NULL, festivalId TEXT NOT NULL,
                "order" INTEGER NOT NULL DEFAULT 0, "group" TEXT, description TEXT,
                base TEXT, area TEXT NOT NULL, image TEXT NOT NULL,
                visibility INTEGER NOT NULL DEFAULT 0, isEditable INTEGER NOT NULL DEFAULT 1
            )
            """)
        try db.execute(sql: """
            CREATE TABLE floatlocations (
                id TEXT PRIMARY KEY NOT NULL, districtId TEXT NOT NULL,
                coordinate TEXT NOT NULL, timestamp TEXT NOT NULL
            )
            """)
        try db.execute(sql: """
            CREATE TABLE performances (
                id TEXT PRIMARY KEY NOT NULL, name TEXT NOT NULL, districtId TEXT NOT NULL,
                performer TEXT NOT NULL, description TEXT
            )
            """)
        try db.execute(sql: """
            CREATE TABLE routes (
                id TEXT PRIMARY KEY NOT NULL, districtId TEXT NOT NULL, periodId TEXT NOT NULL,
                visibility INTEGER NOT NULL DEFAULT 0, description TEXT
            )
            """)
        try db.execute(sql: """
            CREATE TABLE points (
                id TEXT PRIMARY KEY NOT NULL, routeId TEXT NOT NULL, coordinate TEXT NOT NULL,
                time TEXT, checkpointId TEXT, performanceId TEXT, anchor TEXT,
                "index" INTEGER NOT NULL DEFAULT 0, isBoundary INTEGER NOT NULL DEFAULT 0
            )
            """)
        try db.execute(sql: """
            CREATE TABLE routePassages (
                id TEXT PRIMARY KEY NOT NULL, routeId TEXT NOT NULL, districtId TEXT,
                memo TEXT, "order" INTEGER NOT NULL DEFAULT 0
            )
            """)

        try FestivalStoreKey.liveValue.upsert(
            Festival(
                id: "festival-a",
                name: "保存済み祭典",
                subname: "",
                base: Coordinate(latitude: 35, longitude: 139)
            ),
            at: db
        )
        try DistrictStoreKey.liveValue.upsert(
            District(id: "district-a", name: "保存済み町", festivalId: "festival-a"),
            at: db
        )
    }
    return database
}

private final class LaunchCacheUserDefaults: UserDefalutsManagerProtocol, @unchecked Sendable {
    var defaultFestivalId: String?
    var defaultDistrictId: String?
    var hasRequestedAlwaysLocationPermission = false

    init(defaultFestivalId: String?, defaultDistrictId: String?) {
        self.defaultFestivalId = defaultFestivalId
        self.defaultDistrictId = defaultDistrictId
    }

    func setHasRequestedAlwaysLocationPermission(_ value: Bool) {
        hasRequestedAlwaysLocationPermission = value
    }
}

private struct LaunchCacheAuthService: AuthServiceProtocol, Sendable {
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

private struct LaunchCacheAppStatusClient: AppStatusClientProtocol, Sendable {
    func checkStatus() async -> StatusCheckResult? { nil }
    func checkStatus(currentVersion: String) async -> StatusCheckResult? { nil }
    static func getCurrentVersion() -> String { "0" }
}
