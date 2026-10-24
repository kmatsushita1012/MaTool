import ComposableArchitecture
import Dependencies
import Shared
import SQLiteData
import Testing
@testable import iOSApp

@Suite(.serialized)
struct SettingsFeatureSaveFailureTests {
    @Test("祭典保存失敗後は表示と再表示時の祭典が保存済み値に戻る")
    @MainActor
    func festivalSelectionReturnsToSavedValueAfterFailure() async throws {
        let database = try makeDatabase()
        let savedFestival = makeFestival(id: "festival-saved", name: "保存済み祭典")
        let attemptedFestival = makeFestival(id: "festival-attempted", name: "選択した祭典")
        try insert([savedFestival, attemptedFestival], into: database)

        let savedSelection = SceneSelection(festivalId: savedFestival.id, districtId: nil)
        let sceneUsecase = FailingSceneUsecase(savedSelection: savedSelection)
        let initialState = makeState(selection: savedSelection, database: database)
        let store = withDependencies {
            $0.setForSettingsTests(database: database)
            $0[SceneUsecaseKey.self] = sceneUsecase
        } operation: {
            TestStore(initialState: initialState) {
                SettingsFeature()
            }
        }

        let error = AppError.be(.network("保存に失敗しました"))
        await store.send(.binding(.set(\.selectedFestival, attemptedFestival))) {
            $0.selectedFestival = attemptedFestival
            $0.isLoading = true
        }
        await store.receive(.festivalSelectReceived(.failure(error))) {
            $0.selectedFestival = savedFestival
            $0.isLoading = false
            $0.alert = AlertFeature.error("情報の取得に失敗しました 保存に失敗しました")
        }

        let persistedSelection = await sceneUsecase.currentSelection()
        #expect(persistedSelection == savedSelection)
        let reopenedState = makeState(selection: persistedSelection, database: database)
        #expect(reopenedState.selectedFestival == savedFestival)
    }

    @Test("参加町保存失敗後は表示と再表示時の参加町が保存済み値に戻る")
    @MainActor
    func districtSelectionReturnsToSavedValueAfterFailure() async throws {
        let database = try makeDatabase()
        let festival = makeFestival(id: "festival", name: "祭典")
        let savedDistrict = makeDistrict(id: "district-saved", festivalId: festival.id, name: "保存済み町")
        let attemptedDistrict = makeDistrict(id: "district-attempted", festivalId: festival.id, name: "選択した町")
        try insert([festival], into: database)
        try insert([savedDistrict, attemptedDistrict], into: database)

        let savedSelection = SceneSelection(festivalId: festival.id, districtId: savedDistrict.id)
        let sceneUsecase = FailingSceneUsecase(savedSelection: savedSelection)
        let initialState = makeState(selection: savedSelection, database: database)
        let store = withDependencies {
            $0.setForSettingsTests(database: database)
            $0[SceneUsecaseKey.self] = sceneUsecase
        } operation: {
            TestStore(initialState: initialState) {
                SettingsFeature()
            }
        }

        let error = AppError.be(.network("保存に失敗しました"))
        await store.send(.binding(.set(\.selectedDistrict, attemptedDistrict))) {
            $0.selectedDistrict = attemptedDistrict
            $0.isLoading = true
        }
        await store.receive(.districtSelectReceived(.failure(error))) {
            $0.selectedDistrict = savedDistrict
            $0.isLoading = false
            $0.alert = AlertFeature.error("情報の取得に失敗しました 保存に失敗しました")
        }

        let persistedSelection = await sceneUsecase.currentSelection()
        #expect(persistedSelection == savedSelection)
        let reopenedState = makeState(selection: persistedSelection, database: database)
        #expect(reopenedState.selectedDistrict == savedDistrict)
    }
}

private func makeDatabase() throws -> DatabaseQueue {
    let database = try DatabaseQueue(path: ":memory:")
    try database.write { db in
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
    }
    return database
}

private func insert(_ festivals: [Festival], into database: DatabaseQueue) throws {
    try database.write { db in
        try Festival.insert { festivals }.execute(db)
    }
}

private func insert(_ districts: [District], into database: DatabaseQueue) throws {
    try database.write { db in
        try District.insert { districts }.execute(db)
    }
}

private func makeState(selection: SceneSelection, database: DatabaseQueue) -> SettingsFeature.State {
    withDependencies {
        $0.setForSettingsTests(database: database)
    } operation: {
        SettingsFeature.State(selection: selection)
    }
}

private extension DependencyValues {
    mutating func setForSettingsTests(database: DatabaseQueue) {
        defaultDatabase = database
        authService = EmptyAuthService()
        values = ConstantValues(
        apiBaseUrl: "https://example.invalid",
        appStatusUrl: "https://example.invalid/status",
        defaultFestivalKey: "festival",
        defaultDistrictKey: "district",
        loginIdKey: "login",
        hasLaunchedBeforeKey: "hasLaunchedBefore",
        userGuideUrl: "https://example.invalid/guide",
        contactURL: "https://example.invalid/contact",
        isLiquidGlassEnabled: false,
        admobAppId: nil,
            publicMapInterstitialAdUnitId: nil,
            publicMapBannerAdUnitId: nil
        )
        self[FestivalStoreKey.self] = SQLiteStore<Festival>()
        self[CheckpointStoreKey.self] = SQLiteStore<Checkpoint>()
        self[HazardSectionStoreKey.self] = SQLiteStore<HazardSection>()
        self[PeriodStoreKey.self] = SQLiteStore<Period>()
        self[DistrictStoreKey.self] = SQLiteStore<District>()
        self[PerformanceStoreKey.self] = SQLiteStore<Performance>()
        self[RouteStoreKey.self] = SQLiteStore<Route>()
        self[PointStoreKey.self] = SQLiteStore<Point>()
        self[PassageStoreKey.self] = SQLiteStore<RoutePassage>()
        self[FloatLocationStoreKey.self] = SQLiteStore<FloatLocation>()
    }
}

private func makeFestival(id: String, name: String) -> Festival {
    Festival(
        id: id,
        name: name,
        subname: "",
        base: Coordinate(latitude: 0, longitude: 0)
    )
}

private func makeDistrict(id: String, festivalId: Festival.ID, name: String) -> District {
    District(id: id, name: name, festivalId: festivalId)
}

private struct FailingSceneUsecase: SceneUsecaseProtocol {
    let savedSelection: SceneSelection

    func launch() async -> (LaunchState, StatusCheckResult?) {
        (.onboarding, nil)
    }

    func signIn(username: String, password: String) async throws -> SignInState {
        fatalError("Unused in settings save failure tests")
    }

    func isValidPassword(_ password: String) -> Bool {
        false
    }

    func confirmSignIn(password: String) async throws -> UserRole {
        fatalError("Unused in settings save failure tests")
    }

    func currentSelection() async -> SceneSelection {
        savedSelection
    }

    func select(festivalId: Festival.ID) async throws -> FestivalSelectionResult {
        throw AppError.be(.network("保存に失敗しました"))
    }

    func select(districtId: District.ID?) async throws -> Route.ID? {
        throw AppError.be(.network("保存に失敗しました"))
    }
}

private struct EmptyAuthService: AuthServiceProtocol {
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
