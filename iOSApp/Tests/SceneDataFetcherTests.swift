import Dependencies
import Foundation
import Shared
import SQLiteData
import Testing
@testable import iOSApp

@Suite(.serialized)
struct SceneDataFetcherTests {
    @Test("祭典Packの現在地一覧で同じ祭典の欠落位置を消し、他祭典の位置を保持する")
    func festivalPackで位置情報を祭典単位に同期する() async throws {
        let database = try DatabaseQueue(path: ":memory:")
        try await createSceneTables(in: database)

        let festival = Festival(
            id: "festival-a",
            name: "現在の祭典",
            subname: "",
            base: Coordinate(latitude: 35, longitude: 139)
        )
        let otherFestival = Festival(
            id: "festival-b",
            name: "別の祭典",
            subname: "",
            base: Coordinate(latitude: 36, longitude: 140)
        )
        let districtA = District(id: "district-a", name: "A", festivalId: festival.id)
        let districtB = District(id: "district-b", name: "B", festivalId: festival.id)
        let districtC = District(id: "district-c", name: "C", festivalId: otherFestival.id)
        let oldLocationA = FloatLocation(
            id: "old-a",
            districtId: districtA.id,
            coordinate: Coordinate(latitude: 35.1, longitude: 139.1)
        )
        let oldLocationB = FloatLocation(
            id: "old-b",
            districtId: districtB.id,
            coordinate: Coordinate(latitude: 35.2, longitude: 139.2)
        )
        let otherFestivalLocation = FloatLocation(
            id: "location-c",
            districtId: districtC.id,
            coordinate: Coordinate(latitude: 36.1, longitude: 140.1)
        )
        let currentLocationB = FloatLocation(
            id: "new-b",
            districtId: districtB.id,
            coordinate: Coordinate(latitude: 35.3, longitude: 139.3)
        )
        try await database.write { db in
            try SQLiteStore<Festival>().upsert([festival, otherFestival], at: db)
            try SQLiteStore<District>().upsert([districtA, districtB, districtC], at: db)
            try SQLiteStore<FloatLocation>().upsert(
                [oldLocationA, oldLocationB, otherFestivalLocation],
                at: db
            )
        }

        let pack = LaunchFestivalPack(
            festival: festival,
            districts: [districtA, districtB],
            periods: [],
            locations: [currentLocationB],
            checkpoints: [],
            hazardSections: []
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        ScenePackURLProtocol.configure(try encoder.encode(pack))
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [ScenePackURLProtocol.self]
        let httpClient = HTTPClient(
            base: "https://scene-pack-sync.test",
            session: URLSession(configuration: configuration)
        )

        try await withDependencies {
            $0.defaultDatabase = database
            $0.httpClient = httpClient
            $0.authService = SceneRefreshAuthService()
            $0[FestivalStoreKey.self] = SQLiteStore<Festival>()
            $0[CheckpointStoreKey.self] = SQLiteStore<Checkpoint>()
            $0[HazardSectionStoreKey.self] = SQLiteStore<HazardSection>()
            $0[PeriodStoreKey.self] = SQLiteStore<Period>()
            $0[DistrictStoreKey.self] = SQLiteStore<District>()
            $0[PerformanceStoreKey.self] = SQLiteStore<Performance>()
            $0[RouteStoreKey.self] = SQLiteStore<Route>()
            $0[PointStoreKey.self] = SQLiteStore<Point>()
            $0[PassageStoreKey.self] = SQLiteStore<RoutePassage>()
            $0[FloatLocationStoreKey.self] = SQLiteStore<FloatLocation>()
        } operation: {
            try await SceneDataFetcher().launchFestival(
                festivalId: festival.id,
                clearsExistingData: false
            )
        }
        let cacheSettings = ScenePackURLProtocol.lastRequestCacheSettings()
        #expect(cacheSettings.usesProtocolCachePolicy == false)
        #expect(cacheSettings.cacheControl == "no-cache, no-store")

        let locations = try await database.read { db in
            try SQLiteStore<FloatLocation>().fetchAll(from: db)
        }
        #expect(Set(locations.map(\.id)) == ["new-b", "location-c"])
        #expect(locations.first(where: { $0.id == "new-b" })?.coordinate == currentLocationB.coordinate)
        #expect(locations.first(where: { $0.id == "location-c" })?.coordinate == otherFestivalLocation.coordinate)
    }

    @Test("祭典の再取得に失敗した場合は既存データを保持する")
    func festival再取得失敗時に既存データを保持する() async throws {
        let database = try DatabaseQueue(path: ":memory:")
        try await createSceneTables(in: database)

        let festival = Festival(
            id: "festival-old",
            name: "保存済みの祭典",
            subname: "",
            base: Coordinate(latitude: 35, longitude: 139)
        )
        let checkpoint = Checkpoint(id: "checkpoint-old", festivalId: festival.id)
        let hazardSection = HazardSection(id: "hazard-old", festivalId: festival.id)
        let period = Period(
            id: "period-old",
            festivalId: festival.id,
            date: SimpleDate(year: 2026, month: 10, day: 3),
            start: SimpleTime(hour: 9, minute: 0),
            end: SimpleTime(hour: 17, minute: 0)
        )
        let district = District(id: "district-old", name: "保存済みの町", festivalId: festival.id)
        let location = FloatLocation(
            id: "location-old",
            districtId: district.id,
            coordinate: Coordinate(latitude: 35.1, longitude: 139.1),
            timestamp: Date(timeIntervalSince1970: 1_759_452_000)
        )

        try await database.write { db in
            try SQLiteStore<Festival>().upsert(festival, at: db)
            try SQLiteStore<Checkpoint>().upsert(checkpoint, at: db)
            try SQLiteStore<HazardSection>().upsert(hazardSection, at: db)
            try SQLiteStore<Period>().upsert(period, at: db)
            try SQLiteStore<District>().upsert(district, at: db)
            try SQLiteStore<FloatLocation>().upsert(location, at: db)
        }

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [SceneRefreshFailureURLProtocol.self]
        let httpClient = HTTPClient(
            base: "https://scene-refresh-failure.test",
            session: URLSession(configuration: configuration)
        )

        let fetchError: AppError? = await withDependencies {
            $0.defaultDatabase = database
            $0.httpClient = httpClient
            $0.authService = SceneRefreshAuthService()
            $0[FestivalStoreKey.self] = SQLiteStore<Festival>()
            $0[CheckpointStoreKey.self] = SQLiteStore<Checkpoint>()
            $0[HazardSectionStoreKey.self] = SQLiteStore<HazardSection>()
            $0[PeriodStoreKey.self] = SQLiteStore<Period>()
            $0[DistrictStoreKey.self] = SQLiteStore<District>()
            $0[PerformanceStoreKey.self] = SQLiteStore<Performance>()
            $0[RouteStoreKey.self] = SQLiteStore<Route>()
            $0[PointStoreKey.self] = SQLiteStore<Point>()
            $0[PassageStoreKey.self] = SQLiteStore<RoutePassage>()
            $0[FloatLocationStoreKey.self] = SQLiteStore<FloatLocation>()
        } operation: {
            do {
                try await SceneDataFetcher().launchFestival(
                    festivalId: "festival-new",
                    clearsExistingData: true
                )
                return nil
            } catch let error as AppError {
                return error
            } catch {
                return nil
            }
        }

        #expect(fetchError == .be(.network("実行中にエラーが発生しました。インターネット接続を確認してください。")))

        let persisted = try await database.read { db in
            (
                try SQLiteStore<Festival>().fetchAll(from: db),
                try SQLiteStore<Checkpoint>().fetchAll(from: db),
                try SQLiteStore<HazardSection>().fetchAll(from: db),
                try SQLiteStore<Period>().fetchAll(from: db),
                try SQLiteStore<District>().fetchAll(from: db),
                try SQLiteStore<FloatLocation>().fetchAll(from: db)
            )
        }
        #expect(persisted.0 == [festival])
        #expect(persisted.1 == [checkpoint])
        #expect(persisted.2 == [hazardSection])
        #expect(persisted.3 == [period])
        #expect(persisted.4 == [district])
        #expect(persisted.5 == [location])
    }
}

private func createSceneTables(in database: DatabaseQueue) async throws {
    try await database.write { db in
        try #sql("""
            CREATE TABLE "festivals" (
                "id" TEXT PRIMARY KEY NOT NULL,
                "name" TEXT NOT NULL,
                "subname" TEXT NOT NULL,
                "description" TEXT,
                "prefecture" TEXT NOT NULL,
                "city" TEXT NOT NULL,
                "base" TEXT NOT NULL,
                "image" TEXT NOT NULL
            )
        """).execute(db)
        try #sql("""
            CREATE TABLE "checkpoints" (
                "id" TEXT PRIMARY KEY NOT NULL,
                "festivalId" TEXT NOT NULL,
                "name" TEXT NOT NULL,
                "description" TEXT
            )
        """).execute(db)
        try #sql("""
            CREATE TABLE "hazardsections" (
                "id" TEXT PRIMARY KEY NOT NULL,
                "title" TEXT NOT NULL,
                "festivalId" TEXT NOT NULL,
                "coordinates" TEXT NOT NULL
            )
        """).execute(db)
        try #sql("""
            CREATE TABLE "periods" (
                "id" TEXT PRIMARY KEY NOT NULL,
                "festivalId" TEXT NOT NULL,
                "date" TEXT NOT NULL,
                "title" TEXT NOT NULL,
                "start" TEXT NOT NULL,
                "end" TEXT NOT NULL
            )
        """).execute(db)
        try #sql("""
            CREATE TABLE "districts" (
                "id" TEXT PRIMARY KEY NOT NULL,
                "name" TEXT NOT NULL,
                "festivalId" TEXT NOT NULL,
                "order" INTEGER NOT NULL DEFAULT 0,
                "group" TEXT,
                "description" TEXT,
                "base" TEXT,
                "area" TEXT NOT NULL,
                "image" TEXT NOT NULL,
                "visibility" INTEGER NOT NULL DEFAULT 0,
                "isEditable" INTEGER NOT NULL DEFAULT 1
            )
        """).execute(db)
        try #sql("""
            CREATE TABLE "floatlocations" (
                "id" TEXT PRIMARY KEY NOT NULL,
                "districtId" TEXT NOT NULL,
                "coordinate" TEXT NOT NULL,
                "timestamp" TEXT NOT NULL
            )
        """).execute(db)
    }
}

private struct SceneRefreshAuthService: AuthServiceProtocol {
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

private final class SceneRefreshFailureURLProtocol: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool {
        request.url?.host == "scene-refresh-failure.test"
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        client?.urlProtocol(self, didFailWithError: URLError(.notConnectedToInternet))
    }

    override func stopLoading() {}
}

private final class ScenePackURLProtocol: URLProtocol {
    struct RequestCacheSettings {
        let usesProtocolCachePolicy: Bool?
        let cacheControl: String?
    }

    private final class ResponseStore: @unchecked Sendable {
        private let lock = NSLock()
        private var body = Data()
        private var requestCacheSettings = RequestCacheSettings(
            usesProtocolCachePolicy: nil,
            cacheControl: nil
        )

        func set(_ body: Data) {
            lock.lock()
            defer { lock.unlock() }
            self.body = body
            requestCacheSettings = RequestCacheSettings(usesProtocolCachePolicy: nil, cacheControl: nil)
        }

        func get() -> Data {
            lock.lock()
            defer { lock.unlock() }
            return body
        }

        func record(_ request: URLRequest) {
            lock.lock()
            defer { lock.unlock() }
            requestCacheSettings = RequestCacheSettings(
                usesProtocolCachePolicy: request.cachePolicy == .useProtocolCachePolicy,
                cacheControl: request.value(forHTTPHeaderField: "Cache-Control")
            )
        }

        func lastRequestCacheSettings() -> RequestCacheSettings {
            lock.lock()
            defer { lock.unlock() }
            return requestCacheSettings
        }
    }

    private static let responseStore = ResponseStore()

    static func configure(_ body: Data) {
        responseStore.set(body)
    }

    static func lastRequestCacheSettings() -> RequestCacheSettings {
        responseStore.lastRequestCacheSettings()
    }

    override class func canInit(with request: URLRequest) -> Bool {
        request.url?.host == "scene-pack-sync.test"
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        Self.responseStore.record(request)
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: 200,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json"]
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Self.responseStore.get())
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
