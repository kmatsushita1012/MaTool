import ComposableArchitecture
import Shared
import Testing
@testable import iOSApp

struct RootFeatureTests {
    @Test("未ログイン時に地図のgearshapeから設定を開く")
    @MainActor
    func guestGearOpensSettings() async {
        let fixture = RootFeatureFixture()
        let appState = Shared<AppState?>(value: fixture.appState)
        var initialState = RootFeature.State(appState: appState)
        initialState.$launchState.withLock { $0 = .festival(.guest) }
        initialState.map = PublicMapFeature.State(
            festival: fixture.festival,
            userRole: .guest,
            appState: appState
        )
        let selection = SceneSelection(festivalId: fixture.festival.id, districtId: nil)
        let store = TestStore(initialState: initialState) {
            RootFeature()
        } withDependencies: {
            $0.installTestSpies()
            $0.values = rootTestConstantValues()
            $0[FetchFestivalListUseCaseKey.self] = FetchFestivalListUseCaseSpy(festivals: [fixture.festival])
            $0[GetSceneSelectionUseCaseKey.self] = GetSceneSelectionUseCaseSpy(selection: selection)
            $0[LastMainScreenUseCaseKey.self] = LastMainScreenUseCaseSpy()
        }
        store.exhaustivity = .off

        await store.send(.map(.delegate(.settingsOrAdminTapped)))
        await store.receive(.settingsPrepared(.success(SettingsPreparation(
            festivals: [fixture.festival],
            selection: selection
        ))))

        #expect(store.state.destination?.settings != nil)
        await store.finish()
    }

    @Test("ログイン済みの地図から管理画面を開く")
    @MainActor
    func authenticatedGearOpensAdmin() async {
        let fixture = RootFeatureFixture()
        let role = UserRole.headquarter(fixture.festival.id)
        let appState = Shared<AppState?>(value: fixture.appState)
        var initialState = RootFeature.State(appState: appState)
        initialState.$launchState.withLock { $0 = .festival(role) }
        initialState.map = initialState.makeMapState(userRole: role)
        let lastMainScreen = LastMainScreenUseCaseSpy()
        let store = TestStore(initialState: initialState) {
            RootFeature()
        } withDependencies: {
            $0.installTestSpies()
            $0[LastMainScreenUseCaseKey.self] = lastMainScreen
        }
        store.exhaustivity = .off

        await store.send(.map(.delegate(.settingsOrAdminTapped)))

        #expect(store.state.destination?.adminFestival != nil)
        #expect(lastMainScreen.value == .admin)
        await store.finish()
    }

    @Test("ログイン成功時に設定を管理画面へ置き換える")
    @MainActor
    func loginReplacesSettingsWithAdminDestination() async {
        let fixture = RootFeatureFixture()
        let role = UserRole.headquarter(fixture.festival.id)
        let appState = Shared<AppState?>(value: fixture.appState)
        var initialState = RootFeature.State(appState: appState)
        initialState.$launchState.withLock { $0 = .festival(.guest) }
        initialState.map = initialState.makeMapState(userRole: .guest)
        var settingsState = withDependencies {
            $0.installTestSpies()
            $0.values = rootTestConstantValues()
        } operation: {
            SettingsFeature.State(
                selection: SceneSelection(festivalId: fixture.festival.id, districtId: nil),
                festivals: [fixture.festival],
                userRole: .guest,
                appState: appState
            )
        }
        settingsState.destination = .login(LoginFeature.State(appState: appState))
        initialState.destination = .settings(settingsState)
        let lastMainScreen = LastMainScreenUseCaseSpy()
        let store = TestStore(initialState: initialState) {
            RootFeature()
        } withDependencies: {
            $0.installTestSpies()
            $0.values = rootTestConstantValues()
            $0[LastMainScreenUseCaseKey.self] = lastMainScreen
        }
        store.exhaustivity = .off

        await store.send(.destination(.presented(.settings(
            .destination(.presented(.login(.received(.success(.signedIn(role))))))
        ))))

        #expect(store.state.launchState == .festival(role))
        #expect(store.state.map?.userRole == role)
        #expect(store.state.destination?.settings == nil)
        #expect(store.state.destination?.adminFestival != nil)
        #expect(lastMainScreen.value == .admin)
        await store.finish()
    }

    @Test("ログアウト後は管理画面を破棄して地図へ戻る")
    @MainActor
    func signOutClearsAdminDestination() async {
        let fixture = RootFeatureFixture()
        let role = UserRole.headquarter(fixture.festival.id)
        let appState = Shared<AppState?>(value: fixture.appState)
        var initialState = RootFeature.State(appState: appState)
        initialState.$launchState.withLock { $0 = .festival(role) }
        initialState.map = initialState.makeMapState(userRole: role)
        initialState.destination = .adminFestival(.init(fixture.festival, appState: appState))
        let lastMainScreen = LastMainScreenUseCaseSpy(value: .admin)
        let store = TestStore(initialState: initialState) {
            RootFeature()
        } withDependencies: {
            $0.installTestSpies()
            $0[LastMainScreenUseCaseKey.self] = lastMainScreen
        }
        store.exhaustivity = .off

        await store.send(.destination(.presented(.adminFestival(.signOutReceived(.success)))))

        #expect(store.state.launchState == .festival(.guest))
        #expect(store.state.map?.userRole == .guest)
        #expect(store.state.destination == nil)
        #expect(lastMainScreen.value == nil)
        await store.finish()
    }

    @Test("ログイン済みで前回が管理画面なら地図を基点に復元する")
    @MainActor
    func restoresAdminDestinationAboveMap() async {
        let fixture = RootFeatureFixture()
        let role = UserRole.headquarter(fixture.festival.id)
        let lastMainScreen = LastMainScreenUseCaseSpy(value: .admin)
        let initialState = RootFeature.State(appState: Shared(value: Optional(fixture.appState)))
        let store = TestStore(initialState: initialState) {
            RootFeature()
        } withDependencies: {
            $0.installTestSpies()
            $0[LastMainScreenUseCaseKey.self] = lastMainScreen
        }
        store.exhaustivity = .off

        await store.send(.launchFinished(.festival(role), nil))

        #expect(store.state.map != nil)
        #expect(store.state.destination?.adminFestival != nil)
        #expect(store.state.destination?.settings == nil)
        await store.finish()
    }

    @Test("未ログインなら前回の管理画面記録を破棄して地図を表示する")
    @MainActor
    func ignoresRestoredAdminDestinationForGuest() async {
        let fixture = RootFeatureFixture()
        let lastMainScreen = LastMainScreenUseCaseSpy(value: .admin)
        let initialState = RootFeature.State(appState: Shared(value: Optional(fixture.appState)))
        let store = TestStore(initialState: initialState) {
            RootFeature()
        } withDependencies: {
            $0.installTestSpies()
            $0[LastMainScreenUseCaseKey.self] = lastMainScreen
        }
        store.exhaustivity = .off

        await store.send(.launchFinished(.festival(.guest), nil))

        #expect(store.state.map != nil)
        #expect(store.state.destination == nil)
        #expect(lastMainScreen.value == nil)
        await store.finish()
    }

    @Test("ログイン済みで地図を記録している場合は地図を表示する")
    @MainActor
    func restoresMapForAuthenticatedUser() async {
        let fixture = RootFeatureFixture()
        let role = UserRole.headquarter(fixture.festival.id)
        let lastMainScreen = LastMainScreenUseCaseSpy(value: .map)
        let initialState = RootFeature.State(appState: Shared(value: Optional(fixture.appState)))
        let store = TestStore(initialState: initialState) {
            RootFeature()
        } withDependencies: {
            $0.installTestSpies()
            $0[LastMainScreenUseCaseKey.self] = lastMainScreen
        }
        store.exhaustivity = .off

        await store.send(.launchFinished(.festival(role), nil))

        #expect(store.state.map != nil)
        #expect(store.state.destination == nil)
        await store.finish()
    }

    @Test("紹介ボタンは対象画像の読み込み後に該当するSheet rootを表示する")
    @MainActor
    func introductionUsesSelectedMapContent() async {
        let fixture = RootFeatureFixture()
        let appState = Shared<AppState?>(value: fixture.appState)
        var initialState = RootFeature.State(appState: appState)
        initialState.$launchState.withLock { $0 = .festival(.guest) }
        initialState.map = initialState.makeMapState(userRole: .guest)
        let store = TestStore(initialState: initialState) {
            RootFeature()
        } withDependencies: {
            $0.installTestSpies()
            $0[LastMainScreenUseCaseKey.self] = LastMainScreenUseCaseSpy()
            $0[ImageCacheClientKey.self] = ImageCacheClientSpy()
        }
        store.exhaustivity = .off

        await store.send(.map(.delegate(.introductionTapped))) {
            $0.isIntroductionLoading = true
        }
        await store.receive(.introductionPrepared(.success(.festival(fixture.festival)))) {
            $0.isIntroductionLoading = false
            $0.sheet = .festival(FestivalInfoFeature.State(
                fixture.festival,
                appState: appState
            ))
        }
        #expect(store.state.sheet?.festival != nil)

        await store.send(.sheet(.dismiss))
        #expect(store.state.sheet == nil)
        #expect(store.state.map?.selectedContent == .locations)
        await store.finish()

        let routeAppState = Shared<AppState?>(value: fixture.appState)
        var routeInitialState = RootFeature.State(appState: routeAppState)
        routeInitialState.$launchState.withLock { $0 = .district(.guest, nil) }
        routeInitialState.map = PublicMapFeature.State(
            festival: fixture.festival,
            district: fixture.district,
            routeId: nil,
            userRole: .guest,
            appState: routeAppState
        )
        let routeStore = TestStore(initialState: routeInitialState) {
            RootFeature()
        } withDependencies: {
            $0.installTestSpies()
            $0[LastMainScreenUseCaseKey.self] = LastMainScreenUseCaseSpy()
            $0[FetchDistrictUseCaseKey.self] = FetchDistrictUseCaseSpy(
                pack: DistrictPack(district: fixture.district, performances: [])
            )
            $0[ImageCacheClientKey.self] = ImageCacheClientSpy()
        }
        routeStore.exhaustivity = .off

        let pack = DistrictPack(district: fixture.district, performances: [])
        await routeStore.send(.map(.delegate(.introductionTapped))) {
            $0.isIntroductionLoading = true
        }
        await routeStore.receive(.introductionPrepared(.success(.district(fixture.festival, pack, nil)))) {
            $0.isIntroductionLoading = false
            $0.sheet = .district(DistrictIntroductionRootFeature.State(
                pack,
                festival: fixture.festival,
                appState: routeAppState
            ))
        }
        #expect(routeStore.state.sheet?.district != nil)
        #expect(routeStore.state.sheet?.festival == nil)
        await routeStore.finish()
    }

    @Test("屋台アノテーションから対応する町の紹介を開く")
    @MainActor
    func floatAnnotationOpensDistrictIntroduction() async {
        let fixture = RootFeatureFixture()
        let appState = Shared<AppState?>(value: fixture.appState)
        var initialState = RootFeature.State(appState: appState)
        initialState.$launchState.withLock { $0 = .festival(.guest) }
        initialState.map = initialState.makeMapState(userRole: .guest)
        let store = TestStore(initialState: initialState) {
            RootFeature()
        } withDependencies: {
            $0.installTestSpies()
            $0[LastMainScreenUseCaseKey.self] = LastMainScreenUseCaseSpy()
            $0[FetchDistrictUseCaseKey.self] = FetchDistrictUseCaseSpy(
                pack: DistrictPack(district: fixture.district, performances: [])
            )
            $0[ImageCacheClientKey.self] = ImageCacheClientSpy()
        }
        store.exhaustivity = .off

        let entry = FloatEntry(
            floatLocation: FloatLocation(
                id: "float",
                districtId: fixture.district.id,
                coordinate: Coordinate(latitude: 35, longitude: 139)
            ),
            district: fixture.district
        )
        let pack = DistrictPack(district: fixture.district, performances: [])
        await store.send(.map(.destination(.presented(.locations(.floatTapped(entry)))))) {
            $0.isIntroductionLoading = true
        }
        await store.receive(.introductionPrepared(.success(.district(
            fixture.festival, pack, entry.floatLocation.timestamp
        )))) {
            $0.isIntroductionLoading = false
            $0.sheet = .district(DistrictIntroductionRootFeature.State(
                pack,
                festival: fixture.festival,
                locationTimestamp: entry.floatLocation.timestamp,
                appState: appState
            ))
        }

        #expect(store.state.sheet?.district != nil)
        #expect(store.state.map?.selectedContent == .locations)
        await store.finish()
    }

    @Test("設定準備に失敗した後は読み込みを終了して再試行できる")
    @MainActor
    func retriesSettingsPreparationAfterFailure() async {
        let useCase = FailingFestivalListUseCaseSpy()
        let error = AppError.be(.network("network"))
        let fixture = RootFeatureFixture()
        let appState = Shared<AppState?>(value: fixture.appState)
        var initialState = RootFeature.State(appState: appState)
        initialState.$launchState.withLock { $0 = .festival(.guest) }
        initialState.map = PublicMapFeature.State(
            festival: fixture.festival,
            userRole: .guest,
            appState: appState
        )
        let store = TestStore(initialState: initialState) {
            RootFeature()
        } withDependencies: {
            $0.installTestSpies()
            $0.values = rootTestConstantValues()
            $0[FetchFestivalListUseCaseKey.self] = useCase
        }

        await store.send(.map(.delegate(.settingsOrAdminTapped))) {
            $0.isDestinationLoading = true
        }
        await store.receive(.settingsPrepared(.failure(error))) {
            $0.isDestinationLoading = false
            $0.alert = AlertFeature.error("設定画面の準備に失敗しました。\n\(error.message)")
        }

        await store.send(.alert(.presented(.okTapped))) {
            $0.alert = nil
        }
        await store.send(.map(.delegate(.settingsOrAdminTapped))) {
            $0.isDestinationLoading = true
        }
        await store.receive(.settingsPrepared(.failure(error))) {
            $0.isDestinationLoading = false
            $0.alert = AlertFeature.error("設定画面の準備に失敗しました。\n\(error.message)")
        }

        #expect(await useCase.fetchCallCount() == 2)
    }
}

private struct RootFeatureFixture {
    let festival: Festival
    let district: District
    let appState: AppState

    init() {
        festival = Festival(
            id: "festival",
            name: "Festival",
            subname: "Festival",
            base: Coordinate(latitude: 35, longitude: 139)
        )
        district = District(id: "district", name: "District", festivalId: festival.id)
        appState = AppState(
            festivalPack: LaunchFestivalPack(
                festival: festival,
                districts: [district],
                periods: [],
                locations: [],
                checkpoints: [],
                hazardSections: []
            ),
            year: 2026
        )
    }
}

private func rootTestConstantValues() -> ConstantValues {
    ConstantValues(
        apiBaseUrl: "",
        appStatusUrl: "",
        defaultFestivalKey: "festival",
        defaultDistrictKey: "district",
        loginIdKey: "login",
        hasLaunchedBeforeKey: "launched",
        userGuideUrl: "https://example.com/guide",
        contactURL: "https://example.com/contact",
        isLiquidGlassEnabled: false,
        admobAppId: nil,
        publicMapInterstitialAdUnitId: nil,
        publicMapBannerAdUnitId: nil
    )
}
