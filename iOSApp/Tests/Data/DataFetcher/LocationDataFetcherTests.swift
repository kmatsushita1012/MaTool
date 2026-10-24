import Dependencies
import Foundation
import SQLiteData
import Shared
import Testing
@testable import iOSApp

@Suite(.serialized)
struct LocationDataFetcherTests {
    @Test("祭典の位置情報が空ならキャッシュを消し、他祭典の位置は残す")
    func 空の一覧は祭典内の古い位置を削除する() async throws {
        let database = try DatabaseQueue(path: ":memory:")
        try await createTables(in: database)
        try await database.write { db in
            let districts = SQLiteStore<District>()
            let locations = SQLiteStore<FloatLocation>()
            try districts.upsert(
                District(id: "district-a", name: "A", festivalId: "festival-a"),
                at: db
            )
            try districts.upsert(
                District(id: "district-b", name: "B", festivalId: "festival-b"),
                at: db
            )
            try locations.upsert(
                FloatLocation(id: "district-a", districtId: "district-a", coordinate: .init(latitude: 35, longitude: 139)),
                at: db
            )
            try locations.upsert(
                FloatLocation(id: "district-b", districtId: "district-b", coordinate: .init(latitude: 36, longitude: 140)),
                at: db
            )
        }

        LocationResponseURLProtocol.configure(statusCode: 200, body: "[]")
        let client = makeClient()

        try await withDependencies {
            $0.defaultDatabase = database
            $0.httpClient = client
            $0.authProvider = .noop
            $0[AuthServiceKey.self] = AuthService()
            $0[DistrictStoreKey.self] = SQLiteStore<District>()
            $0[FloatLocationStoreKey.self] = SQLiteStore<FloatLocation>()
        } operation: {
            try await LocationDataFetcher().fetchAll(festivalId: "festival-a")
        }
        let cacheSettings = LocationResponseURLProtocol.lastRequestCacheSettings()
        #expect(cacheSettings.usesProtocolCachePolicy == false)
        #expect(cacheSettings.cacheControl == "no-cache, no-store")

        let remainingLocations = try await database.read { db in
            try SQLiteStore<FloatLocation>().fetchAll(from: db)
        }
        #expect(remainingLocations.map(\.districtId) == ["district-b"])
    }

    @Test("地区位置の404と401はその地区だけをキャッシュから削除する")
    func 地区位置が利用不可なら対象地区だけ削除する() async throws {
        for statusCode in [401, 404] {
            let database = try await databaseWithCachedLocations()
            LocationResponseURLProtocol.configure(
                statusCode: statusCode,
                body: #"{"message":"Unavailable","localizedDescription":"現在地を取得できません"}"#
            )

            var receivedError: Error?
            do {
                try await withDependencies {
                    $0.defaultDatabase = database
                    $0.httpClient = makeClient()
                    $0.authProvider = .noop
                    $0[AuthServiceKey.self] = AuthService()
                    $0[DistrictStoreKey.self] = SQLiteStore<District>()
                    $0[FloatLocationStoreKey.self] = SQLiteStore<FloatLocation>()
                } operation: {
                    try await LocationDataFetcher().fetch(districtId: "district-a")
                }
            } catch {
                receivedError = error
            }

            let cacheSettings = LocationResponseURLProtocol.lastRequestCacheSettings()
            #expect(cacheSettings.usesProtocolCachePolicy == false)
            #expect(cacheSettings.cacheControl == "no-cache, no-store")
            let expectedError: AppError = statusCode == 401
                ? .be(.unauthorized("現在地を取得できません"))
                : .be(.notFound("現在地を取得できません"))
            #expect(receivedError?.asAppError == expectedError)
            let remainingDistrictIds = try await database.read { db in
                try SQLiteStore<FloatLocation>().fetchAll(from: db).map(\.districtId).sorted()
            }
            #expect(remainingDistrictIds == ["district-b", "district-c"])
        }
    }

    @Test("地区位置の一時的なAPIエラーでは既存キャッシュを保持する")
    func 地区位置が一時的に取得できなくてもキャッシュを保持する() async throws {
        for statusCode in [503, 500] {
            let database = try await databaseWithCachedLocations()
            LocationResponseURLProtocol.configure(
                statusCode: statusCode,
                body: #"{"message":"Unavailable","localizedDescription":"一時的なサーバーエラー"}"#
            )

            do {
                try await withDependencies {
                    $0.defaultDatabase = database
                    $0.httpClient = makeClient()
                    $0.authProvider = .noop
                    $0[AuthServiceKey.self] = AuthService()
                    $0[DistrictStoreKey.self] = SQLiteStore<District>()
                    $0[FloatLocationStoreKey.self] = SQLiteStore<FloatLocation>()
                } operation: {
                    try await LocationDataFetcher().fetch(districtId: "district-a")
                }
                Issue.record("API error should be propagated")
            } catch {
                #expect(error.asAppError == .be(.server(
                    statusCode: statusCode,
                    message: "一時的なサーバーエラー"
                )))
            }

            let remainingDistrictIds = try await database.read { db in
                try SQLiteStore<FloatLocation>().fetchAll(from: db).map(\.districtId).sorted()
            }
            #expect(remainingDistrictIds == ["district-a", "district-b", "district-c"])
        }
    }

    @Test("通信失敗では既存の地区位置キャッシュを保持する")
    func 地区位置の通信失敗でもキャッシュを保持する() async throws {
        for errorCode in [URLError.Code.notConnectedToInternet, .timedOut] {
            let database = try await databaseWithCachedLocations()
            LocationResponseURLProtocol.configure(errorCode: errorCode)

            do {
                try await withDependencies {
                    $0.defaultDatabase = database
                    $0.httpClient = makeClient()
                    $0.authProvider = .noop
                    $0[AuthServiceKey.self] = AuthService()
                    $0[DistrictStoreKey.self] = SQLiteStore<District>()
                    $0[FloatLocationStoreKey.self] = SQLiteStore<FloatLocation>()
                } operation: {
                    try await LocationDataFetcher().fetch(districtId: "district-a")
                }
                Issue.record("Network error should be propagated")
            } catch {
                #expect(error.asAppError == .be(.network(
                    "実行中にエラーが発生しました。インターネット接続を確認してください。"
                )))
            }

            let remainingDistrictIds = try await database.read { db in
                try SQLiteStore<FloatLocation>().fetchAll(from: db).map(\.districtId).sorted()
            }
            #expect(remainingDistrictIds == ["district-a", "district-b", "district-c"])
        }
    }

    @Test("地区位置GETの空応答はその地区だけキャッシュから削除する")
    func 地区位置がnilなら対象地区だけ削除する() async throws {
        let database = try await databaseWithCachedLocations()
        LocationResponseURLProtocol.configure(statusCode: 200, body: "null")

        try await withDependencies {
            $0.defaultDatabase = database
            $0.httpClient = makeClient()
            $0.authProvider = .noop
            $0[AuthServiceKey.self] = AuthService()
            $0[DistrictStoreKey.self] = SQLiteStore<District>()
            $0[FloatLocationStoreKey.self] = SQLiteStore<FloatLocation>()
        } operation: {
            try await LocationDataFetcher().fetch(districtId: "district-a")
        }

        let remainingDistrictIds = try await database.read { db in
            try SQLiteStore<FloatLocation>().fetchAll(from: db).map(\.districtId).sorted()
        }
        #expect(remainingDistrictIds == ["district-b", "district-c"])
    }

    @Test("位置情報一覧の401は祭典内のキャッシュを削除しない")
    func 祭典位置一覧の認証エラーではキャッシュを保持する() async throws {
        let database = try await databaseWithCachedLocations()
        LocationResponseURLProtocol.configure(
            statusCode: 401,
            body: #"{"message":"Unavailable","localizedDescription":"祭典が見つかりません"}"#
        )

        do {
            try await withDependencies {
                $0.defaultDatabase = database
                $0.httpClient = makeClient()
                $0.authProvider = .noop
                $0[AuthServiceKey.self] = AuthService()
                $0[DistrictStoreKey.self] = SQLiteStore<District>()
                $0[FloatLocationStoreKey.self] = SQLiteStore<FloatLocation>()
            } operation: {
                try await LocationDataFetcher().fetchAll(festivalId: "festival-a")
            }
            Issue.record("API error should be propagated")
        } catch {
            #expect(error.asAppError == .be(.unauthorized("祭典が見つかりません")))
        }

        let remainingDistrictIds = try await database.read { db in
            try SQLiteStore<FloatLocation>().fetchAll(from: db).map(\.districtId).sorted()
        }
        #expect(remainingDistrictIds == ["district-a", "district-b", "district-c"])
    }

    @Test("位置情報一覧の5xxでは既存キャッシュを保持する")
    func 祭典位置一覧が一時的に取得できなくてもキャッシュを保持する() async throws {
        let database = try await databaseWithCachedLocations()
        LocationResponseURLProtocol.configure(
            statusCode: 503,
            body: #"{"message":"Unavailable","localizedDescription":"一時的なサーバーエラー"}"#
        )

        do {
            try await withDependencies {
                $0.defaultDatabase = database
                $0.httpClient = makeClient()
                $0.authProvider = .noop
                $0[AuthServiceKey.self] = AuthService()
                $0[DistrictStoreKey.self] = SQLiteStore<District>()
                $0[FloatLocationStoreKey.self] = SQLiteStore<FloatLocation>()
            } operation: {
                try await LocationDataFetcher().fetchAll(festivalId: "festival-a")
            }
            Issue.record("API error should be propagated")
        } catch {
            #expect(error.asAppError == .be(.server(
                statusCode: 503,
                message: "一時的なサーバーエラー"
            )))
        }

        let remainingDistrictIds = try await database.read { db in
            try SQLiteStore<FloatLocation>().fetchAll(from: db).map(\.districtId).sorted()
        }
        #expect(remainingDistrictIds == ["district-a", "district-b", "district-c"])
    }

    private func databaseWithCachedLocations() async throws -> DatabaseQueue {
        let database = try DatabaseQueue(path: ":memory:")
        try await createTables(in: database)
        try await database.write { db in
            let districts = SQLiteStore<District>()
            let locations = SQLiteStore<FloatLocation>()
            try districts.upsert(
                District(id: "district-a", name: "A", festivalId: "festival-a"),
                at: db
            )
            try districts.upsert(
                District(id: "district-b", name: "B", festivalId: "festival-a"),
                at: db
            )
            try districts.upsert(
                District(id: "district-c", name: "C", festivalId: "festival-b"),
                at: db
            )
            try locations.upsert(
                FloatLocation(id: "district-a", districtId: "district-a", coordinate: .init(latitude: 35, longitude: 139)),
                at: db
            )
            try locations.upsert(
                FloatLocation(id: "district-b", districtId: "district-b", coordinate: .init(latitude: 36, longitude: 140)),
                at: db
            )
            try locations.upsert(
                FloatLocation(id: "district-c", districtId: "district-c", coordinate: .init(latitude: 37, longitude: 141)),
                at: db
            )
        }
        return database
    }

    private func makeClient() -> HTTPClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [LocationResponseURLProtocol.self]
        return HTTPClient(
            base: "https://location-sync.test",
            session: URLSession(configuration: configuration)
        )
    }

    private func createTables(in database: DatabaseQueue) async throws {
        try await database.write { db in
            try db.execute(sql: """
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
                """)
            try db.execute(sql: """
                CREATE TABLE floatlocations (
                    id TEXT PRIMARY KEY NOT NULL,
                    districtId TEXT NOT NULL,
                    coordinate TEXT NOT NULL,
                    timestamp TEXT NOT NULL
                )
                """)
        }
    }
}

private final class EmptyLocationListURLProtocol: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool {
        request.url?.host == "location-sync.test"
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: 200,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json"]
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data("[]".utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

private final class LocationResponseURLProtocol: URLProtocol {
    struct RequestCacheSettings {
        let usesProtocolCachePolicy: Bool?
        let cacheControl: String?
    }

    private struct Fixture: Sendable {
        let statusCode: Int
        let body: Data
        let errorCode: URLError.Code?
    }

    private final class FixtureStore: @unchecked Sendable {
        private let lock = NSLock()
        private var fixture = Fixture(statusCode: 200, body: Data("[]".utf8), errorCode: nil)
        private var requestCacheSettings = RequestCacheSettings(
            usesProtocolCachePolicy: nil,
            cacheControl: nil
        )

        func configure(statusCode: Int, body: String) {
            lock.lock()
            defer { lock.unlock() }
            fixture = Fixture(statusCode: statusCode, body: Data(body.utf8), errorCode: nil)
            requestCacheSettings = RequestCacheSettings(usesProtocolCachePolicy: nil, cacheControl: nil)
        }

        func configure(errorCode: URLError.Code) {
            lock.lock()
            defer { lock.unlock() }
            fixture = Fixture(statusCode: 0, body: Data(), errorCode: errorCode)
            requestCacheSettings = RequestCacheSettings(usesProtocolCachePolicy: nil, cacheControl: nil)
        }

        func snapshot() -> Fixture {
            lock.lock()
            defer { lock.unlock() }
            return fixture
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

    private static let fixtureStore = FixtureStore()

    static func configure(statusCode: Int, body: String) {
        fixtureStore.configure(statusCode: statusCode, body: body)
    }

    static func configure(errorCode: URLError.Code) {
        fixtureStore.configure(errorCode: errorCode)
    }

    static func lastRequestCacheSettings() -> RequestCacheSettings {
        fixtureStore.lastRequestCacheSettings()
    }

    override class func canInit(with request: URLRequest) -> Bool {
        request.url?.host == "location-sync.test"
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.fixtureStore.record(request)
        let fixture = Self.fixtureStore.snapshot()
        if let errorCode = fixture.errorCode {
            client?.urlProtocol(self, didFailWithError: URLError(errorCode))
            return
        }

        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: fixture.statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json"]
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: fixture.body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
