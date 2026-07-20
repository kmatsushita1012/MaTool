//
//  SceneUsecaseLaunchTests.swift
//  MaToolTests
//
//  Created by Codex on 2026/06/30.
//

import Dependencies
import Shared
import Testing
@testable import iOSApp

struct SceneUsecaseLaunchTests {
    @Test("起動失敗が一時的なエラーなら保存済み選択を消さない")
    func 起動失敗が一時的なエラーなら保存済み選択を消さない() async {
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

        let usecase = makeUsecase(
            userDefaults: userDefaults,
            festivalDataFetcher: festivalDataFetcher,
            sceneDataFetcher: sceneDataFetcher
        )

        let (launchState, _) = await usecase.launch()

        switch launchState {
        case .error(let message):
            #expect(message == "network")
        default:
            Issue.record("error になる想定でした")
        }
        #expect(userDefaults.defaultFestivalId == "festival-a")
        #expect(userDefaults.defaultDistrictId == "district-a")
        #expect(await festivalDataFetcher.didFetchAll() == false)
    }

    @Test("起動失敗が notFound なら保存済み選択を消して onboarding に戻す")
    func 起動失敗がnotFoundなら保存済み選択を消してonboardingに戻す() async {
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

        let usecase = makeUsecase(
            userDefaults: userDefaults,
            festivalDataFetcher: festivalDataFetcher,
            sceneDataFetcher: sceneDataFetcher
        )

        let (launchState, _) = await usecase.launch()

        switch launchState {
        case .onboarding:
            break
        default:
            Issue.record("onboarding に戻る想定でした")
        }
        #expect(userDefaults.defaultFestivalId == nil)
        #expect(userDefaults.defaultDistrictId == nil)
        #expect(await festivalDataFetcher.didFetchAll())
    }
}

private func makeUsecase(
    userDefaults: InMemoryUserDefaultsManager,
    festivalDataFetcher: FestivalDataFetcherMock,
    sceneDataFetcher: SceneDataFetcherMock
) -> SceneUsecase {
    withDependencies {
        $0.authService = AuthServiceMock()
        $0.appStatusClient = AppStatusClientMock()
        $0.festivalDataFetcher = festivalDataFetcher
        $0[SceneDataFetcherKey.self] = sceneDataFetcher
    } operation: {
        SceneUsecase(userDefaults: userDefaults)
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

private struct SceneDataFetcherMock: SceneDataFetcherProtocol, Sendable {
    let launchFestivalHandler: @Sendable (Festival.ID) async throws -> Void
    let launchFestivalFromDistrictHandler: @Sendable (District.ID) async throws -> Festival.ID
    let launchDistrictHandler: @Sendable (District.ID, Period.ID?, Bool) async throws -> Route.ID?

    init(
        launchFestivalHandler: @escaping @Sendable (Festival.ID) async throws -> Void = { _ in },
        launchFestivalFromDistrictHandler: @escaping @Sendable (District.ID) async throws -> Festival.ID = { _ in "festival-a" },
        launchDistrictHandler: @escaping @Sendable (District.ID, Period.ID?, Bool) async throws -> Route.ID? = { _, _, _ in nil }
    ) {
        self.launchFestivalHandler = launchFestivalHandler
        self.launchFestivalFromDistrictHandler = launchFestivalFromDistrictHandler
        self.launchDistrictHandler = launchDistrictHandler
    }

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

private struct AuthServiceMock: AuthServiceProtocol, Sendable {
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

private struct AppStatusClientMock: AppStatusClientProtocol, Sendable {
    func checkStatus() async -> StatusCheckResult? { nil }
    func checkStatus(currentVersion: String) async -> StatusCheckResult? { nil }
    static func getCurrentVersion() -> String { "1.0.0" }
}
