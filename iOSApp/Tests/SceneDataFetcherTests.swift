import Dependencies
import Foundation
import Shared
import SQLiteData
import Testing
@testable import iOSApp

@Suite(.serialized)
struct SceneDataFetcherTests {
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
