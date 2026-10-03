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

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [EmptyLocationListURLProtocol.self]
        let client = HTTPClient(
            base: "https://location-sync.test",
            session: URLSession(configuration: configuration)
        )

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

        let remainingLocations = try await database.read { db in
            try SQLiteStore<FloatLocation>().fetchAll(from: db)
        }
        #expect(remainingLocations.map(\.districtId) == ["district-b"])
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
