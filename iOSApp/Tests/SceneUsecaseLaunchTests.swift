//
//  SceneUsecaseLaunchTests.swift
//  MaToolTests
//
//  Created by Codex on 2026/06/30.
//

import XCTest
import Dependencies
import Shared
@testable import iOSApp

final class SceneUsecaseLaunchTests: XCTestCase {
    func test起動失敗が一時的なエラーなら保存済み選択を消さない() async {
        let userDefaults = InMemoryUserDefaultsManager(
            defaultFestivalId: "festival-a",
            defaultDistrictId: "district-a"
        )
        let festivalDataFetcher = FestivalDataFetcherMock()
        let sceneDataFetcher = SceneDataFetcherMock(
            launchFestivalHandler: { _ in
                throw AppError.be(.network("network"))
            }
        )

        let usecase = withDependencies {
            $0.authService = AuthServiceMock()
            $0.appStatusClient = AppStatusClientMock()
            $0.festivalDataFetcher = festivalDataFetcher
            $0.sceneDataFetcher = sceneDataFetcher
        } operation: {
            SceneUsecase(userDefaults: userDefaults)
        }

        let (launchState, _) = await usecase.launch()

        if case .error(let message) = launchState {
            XCTAssertEqual(message, "network")
        } else {
            XCTFail("error になる想定でした")
        }
        XCTAssertEqual(userDefaults.defaultFestivalId, "festival-a")
        XCTAssertEqual(userDefaults.defaultDistrictId, "district-a")
        XCTAssertFalse(await festivalDataFetcher.didFetchAll())
    }

    func test起動失敗がnotFoundなら保存済み選択を消してonboardingに戻す() async {
        let userDefaults = InMemoryUserDefaultsManager(
            defaultFestivalId: "festival-a",
            defaultDistrictId: "district-a"
        )
        let festivalDataFetcher = FestivalDataFetcherMock()
        let sceneDataFetcher = SceneDataFetcherMock(
            launchFestivalHandler: { _ in
                throw AppError.be(.notFound("missing"))
            }
        )

        let usecase = withDependencies {
            $0.authService = AuthServiceMock()
            $0.appStatusClient = AppStatusClientMock()
            $0.festivalDataFetcher = festivalDataFetcher
            $0.sceneDataFetcher = sceneDataFetcher
        } operation: {
            SceneUsecase(userDefaults: userDefaults)
        }

        let (launchState, _) = await usecase.launch()

        if case .onboarding = launchState {
        } else {
            XCTFail("onboarding に戻る想定でした")
        }
        XCTAssertNil(userDefaults.defaultFestivalId)
        XCTAssertNil(userDefaults.defaultDistrictId)
        XCTAssertTrue(await festivalDataFetcher.didFetchAll())
    }
}

private final class InMemoryUserDefaultsManager: UserDefalutsManagerProtocol, @unchecked Sendable {
    var defaultFestivalId: String?
    var defaultDistrictId: String?

    init(defaultFestivalId: String?, defaultDistrictId: String?) {
        self.defaultFestivalId = defaultFestivalId
        self.defaultDistrictId = defaultDistrictId
    }
}

private actor FestivalDataFetcherMock: FestivalDataFetcherProtocol {
    private var fetchAllCalled = false

    func update(festival: Festival, checkPoints: [Checkpoint], hazardSections: [HazardSection]) async throws {}

    func fetchAll() async throws {
        fetchAllCalled = true
    }

    func fetch(festivalID: Festival.ID) async throws {}

    func didFetchAll() -> Bool {
        fetchAllCalled
    }
}

private struct SceneDataFetcherMock: SceneDataFetcherProtocol {
    var launchFestivalHandler: @Sendable (Festival.ID) async throws -> Void = { _ in }
    var launchFestivalFromDistrictHandler: @Sendable (District.ID) async throws -> Festival.ID = { _ in "festival-a" }
    var launchDistrictHandler: @Sendable (District.ID, Period.ID?, Bool) async throws -> Route.ID? = { _, _, _ in nil }

    func launchFestival(festivalId: Festival.ID, clearsExistingData: Bool) async throws {
        try await launchFestivalHandler(festivalId)
    }

    func launchFestival(districtId: District.ID, clearsExistingData: Bool) async throws -> Festival.ID {
        try await launchFestivalFromDistrictHandler(districtId)
    }

    func launchDistrict(districtId: District.ID, periodId: Period.ID?, clearsExistingData: Bool) async throws -> Route.ID? {
        try await launchDistrictHandler(districtId, periodId, clearsExistingData)
    }
}

private struct AuthServiceMock: AuthServiceProtocol {
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

private struct AppStatusClientMock: AppStatusClientProtocol {
    func checkStatus() async -> StatusCheckResult? { nil }
    func checkStatus(currentVersion: String) async -> StatusCheckResult? { nil }
    static func getCurrentVersion() -> String { "1.0.0" }
}
