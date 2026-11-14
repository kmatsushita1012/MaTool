import ComposableArchitecture
import Foundation
import Shared
import Testing
@testable import iOSApp

struct RootFeatureTests {
    @Test("ゲスト権限では管理画面の遷移先を構築できない")
    @MainActor
    func guestRoleCannotCreateAdminDestination() {
        let fixture = RootFeatureFixture()
        for role in [UserRole.guest, .advertiser("owner-1")] {
            var state = RootFeature.State(appState: Shared<AppState?>(value: fixture.appState))
            let changed = RootFeature().setAdminDestination(state: &state, userRole: role)

            #expect(!changed)
            #expect(state.destination == nil)
            #expect(state.alert == nil)
        }
    }

    @Test("起動結果が未設定ユーザーなら地図を作らずOnboardingの祭典一覧を一度取得する")
    @MainActor
    func onboardingLaunchLoadsFestivalOptions() async {
        let fixture = RootFeatureFixture()
        let store = TestStore(initialState: RootFeature.State(
            appState: Shared<AppState?>(value: fixture.appState)
        )) {
            RootFeature()
        } withDependencies: {
            $0.installTestSpies()
            $0[FetchFestivalListUseCaseKey.self] = FetchFestivalListUseCaseSpy(
                festivals: [fixture.festival]
            )
        }
        store.exhaustivity = .off

        await store.send(.launchFinished(.onboarding, nil))
        await store.receive(.onboarding(.onAppear))
        await store.receive(.onboarding(.festivalsLoaded(.success([fixture.festival]))))
        #expect(store.state.map == nil)
        #expect(store.state.destination == nil)
        #expect(store.state.onboarding?.festivals == [fixture.festival])
        await store.finish()
    }

    @Test("設定画面で町の経路を選ぶと管理権限と経路を保持して地図を更新する")
    @MainActor
    func selectingDistrictRouteUpdatesMapWithoutDroppingSelection() async {
        let fixture = RootFeatureFixture()
        let appState = Shared<AppState?>(value: AppStateFixture.state())
        var initial = RootFeature.State(appState: appState)
        initial.$launchState.withLock { $0 = .festival(.guest) }
        initial.map = initial.makeMapState(userRole: .guest)
        initial.destination = .settings(withDependencies {
            $0.installTestSpies()
            $0.values = rootTestConstantValues()
        } operation: {
            SettingsFeature.State(
                selection: .init(festivalId: fixture.festival.id, districtId: nil),
                festivals: [fixture.festival],
                userRole: .guest,
                appState: appState
            )
        })
        let store = TestStore(initialState: initial) {
            RootFeature()
        } withDependencies: {
            $0.installTestSpies()
            $0.values = rootTestConstantValues()
        }
        store.exhaustivity = .off

        let role = UserRole.district(fixture.district.id)
        await store.send(.destination(.presented(.settings(
            .delegate(.sceneSelectionChanged(role, "route"))
        ))))
        #expect(store.state.launchState == .district(role, "route"))
        #expect(store.state.map?.userRole == role)
        #expect(store.state.map?.selectedContent == .route(fixture.district.id))
        await store.finish()
    }

    @Test("祭典の管理画面からログアウトして町を選択した状態に戻る場合も経路を保持する")
    @MainActor
    func signOutRestoresDistrictRouteSelection() async {
        let fixture = RootFeatureFixture()
        let appState = Shared<AppState?>(value: AppStateFixture.state())
        let role = UserRole.headquarter(fixture.festival.id)
        var initial = RootFeature.State(appState: appState)
        initial.$launchState.withLock { $0 = .festival(role) }
        initial.map = initial.makeMapState(userRole: role)
        initial.destination = .adminFestival(.init(fixture.festival, appState: appState))
        let lastScreen = LastMainScreenUseCaseSpy(value: .admin)
        let store = TestStore(initialState: initial) {
            RootFeature()
        } withDependencies: {
            $0.installTestSpies()
            $0[LastMainScreenUseCaseKey.self] = lastScreen
        }
        store.exhaustivity = .off

        await store.send(.destination(.presented(.adminFestival(
            .signOutReceived(.success(.district(.guest, "route")))
        ))))
        #expect(store.state.launchState == .district(.guest, "route"))
        #expect(store.state.map?.selectedContent == .route(fixture.district.id))
        #expect(store.state.map?.userRole == .guest)
        #expect(store.state.destination == nil)
        #expect(lastScreen.value == nil)
        await store.finish()
    }

    @Test("Rootの設定画面でライセンスを開いても親の管理先と地図は切り替えない")
    @MainActor
    func licenseNavigationRemainsInSettingsChild() async {
        let fixture = RootFeatureFixture()
        let appState = Shared<AppState?>(value: fixture.appState)
        var initial = RootFeature.State(appState: appState)
        initial.$launchState.withLock { $0 = .festival(.guest) }
        initial.map = initial.makeMapState(userRole: .guest)
        initial.destination = .settings(withDependencies {
            $0.installTestSpies()
            $0.values = rootTestConstantValues()
        } operation: {
            SettingsFeature.State(
                selection: SceneSelection(festivalId: fixture.festival.id, districtId: nil),
                festivals: [fixture.festival],
                userRole: .guest,
                appState: appState
            )
        })
        let store = TestStore(initialState: initial) {
            RootFeature()
        } withDependencies: {
            $0.installTestSpies()
            $0.values = rootTestConstantValues()
        }
        store.exhaustivity = .off

        await store.send(.destination(.presented(.settings(.licenseTapped))))
        #expect(store.state.destination?.settings?.navigationDestination == .license)
        #expect(store.state.map?.userRole == .guest)
        await store.finish()
    }

    @Test("Onboardingで祭典一覧の読み込みに失敗した場合はRootをエラー画面へ切り替えない")
    @MainActor
    func onboardingFetchFailureStaysInsideChildWithoutLosingScene() async {
        var initial = RootFeature.State()
        initial.$launchState.withLock { $0 = .onboarding }
        initial.onboarding = initial.makeOnboardingState()
        let store = TestStore(initialState: initial) {
            RootFeature()
        } withDependencies: { $0.installTestSpies() }
        store.exhaustivity = .off

        let error = AppError.be(.network("offline"))
        await store.send(.onboarding(.festivalsLoaded(.failure(error))))
        #expect(store.state.scene == .onboarding)
        #expect(store.state.onboarding?.festivalErrorMessaage == error.message)
        #expect(store.state.map == nil)
        await store.finish()
    }

    @Test("経路地図の屋台配信位置から町紹介を開くと配信時刻を紹介画面へ引き継ぐ")
    @MainActor
    func routeMapAnnotationOpensDistrictIntroduction() async {
        let fixture = RootFeatureFixture()
        let appState = Shared<AppState?>(value: AppStateFixture.state())
        var initial = RootFeature.State(appState: appState)
        initial.$launchState.withLock { $0 = .district(.guest, nil) }
        initial.map = PublicMapFeature.State(
            festival: fixture.festival,
            district: fixture.district,
            routeId: nil,
            userRole: .guest,
            appState: appState
        )
        let pack = DistrictPack(district: fixture.district, performances: [])
        let store = TestStore(initialState: initial) {
            RootFeature()
        } withDependencies: {
            $0.installTestSpies()
            $0[FetchDistrictUseCaseKey.self] = FetchDistrictUseCaseSpy(pack: pack)
            $0[ImageCacheClientKey.self] = ImageCacheClientSpy()
        }
        store.exhaustivity = .off

        let entry = FloatEntry(
            floatLocation: FloatLocation(
                id: "route-float",
                districtId: fixture.district.id,
                coordinate: Coordinate(latitude: 35.1, longitude: 139.1)
            ),
            district: fixture.district
        )
        #expect(store.state.map?.destination?.route != nil)
        await store.send(.map(.destination(.presented(.route(.locationTapped(entry))))))
        await store.receive(.introductionPrepared(.success(.district(
            fixture.festival, pack, entry.floatLocation.timestamp
        ))))
        #expect(store.state.sheet?.district != nil)
        #expect(store.state.map?.selectedContent == .route(fixture.district.id))
        await store.finish()
    }

    @Test("本部管理画面の町一覧遷移はRootの画面スタックを置き換えず子画面だけを開く")
    @MainActor
    func adminChildNavigationDoesNotReplaceRootDestination() async {
        let fixture = RootFeatureFixture()
        let appState = Shared<AppState?>(value: fixture.appState)
        let role = UserRole.headquarter(fixture.festival.id)
        var initial = RootFeature.State(appState: appState)
        initial.$launchState.withLock { $0 = .festival(role) }
        initial.map = initial.makeMapState(userRole: role)
        initial.destination = .adminFestival(.init(fixture.festival, appState: appState))
        let store = TestStore(initialState: initial) {
            RootFeature()
        } withDependencies: { $0.installTestSpies() }
        store.exhaustivity = .off

        await store.send(.destination(.presented(.adminFestival(.districtsTapped))))
        #expect(store.state.destination?.adminFestival?.destination?.districts != nil)
        #expect(store.state.launchState == .festival(role))
        #expect(store.state.map != nil)
        await store.finish()
    }

    @Test("最初のlaunchだけがUseCaseを呼び、取得したゲストシーンへ遷移する")
    @MainActor
    func firstLaunchFetchesSceneExactlyOnce() async {
        let fixture = RootFeatureFixture()
        let launchSpy = RootLaunchSuccessSpy(result: .festival(.guest))
        let lastScreen = LastMainScreenUseCaseSpy()
        let store = TestStore(initialState: RootFeature.State(
            appState: Shared<AppState?>(value: fixture.appState)
        )) {
            RootFeature()
        } withDependencies: {
            $0.installTestSpies()
            $0[LaunchSceneUseCaseKey.self] = launchSpy
            $0[LastMainScreenUseCaseKey.self] = lastScreen
        }
        store.exhaustivity = .off

        await store.send(.launch)
        #expect(store.state.didLaunch)
        await store.receive(.launchFinished(.festival(.guest), nil))
        #expect(store.state.map != nil)
        #expect(store.state.launchState == .festival(.guest))
        await store.send(.launch)
        #expect(await launchSpy.calls == 1)
        await store.finish()
    }

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

    @Test("町管理者としてログインした場合は地区IDを維持し地図と管理画面を更新する")
    @MainActor
    func districtLoginActivatesCorrespondingAdminDashboard() async {
        let fixture = RootFeatureFixture()
        let role = UserRole.district(fixture.district.id)
        let appState = Shared<AppState?>(value: fixture.appState)
        var initial = RootFeature.State(appState: appState)
        initial.$launchState.withLock { $0 = .festival(.guest) }
        initial.map = initial.makeMapState(userRole: .guest)
        var settings = withDependencies {
            $0.installTestSpies()
            $0.values = rootTestConstantValues()
        } operation: {
            SettingsFeature.State(
                selection: .init(festivalId: fixture.festival.id, districtId: nil),
                festivals: [fixture.festival],
                userRole: .guest,
                appState: appState
            )
        }
        settings.destination = .login(LoginFeature.State(appState: appState))
        initial.destination = .settings(settings)
        let lastScreen = LastMainScreenUseCaseSpy()
        let store = TestStore(initialState: initial) {
            RootFeature()
        } withDependencies: {
            $0.installTestSpies()
            $0.values = rootTestConstantValues()
            $0[LastMainScreenUseCaseKey.self] = lastScreen
        }
        store.exhaustivity = .off

        await store.send(.destination(.presented(.settings(
            .destination(.presented(.login(.received(.success(.signedIn(role))))))
        ))))
        #expect(store.state.launchState == .district(role, nil))
        #expect(store.state.map?.userRole == role)
        #expect(store.state.destination?.adminDistrict != nil)
        #expect(lastScreen.value == .admin)
        await store.finish()
    }

    @Test("ゲスト権限を管理者ログイン成功として受け取っても管理画面への昇格を拒否する")
    @MainActor
    func guestLoginResponseCannotActivateAdminDashboard() async {
        let fixture = RootFeatureFixture()
        let appState = Shared<AppState?>(value: fixture.appState)
        var initial = RootFeature.State(appState: appState)
        initial.$launchState.withLock { $0 = .festival(.guest) }
        initial.map = initial.makeMapState(userRole: .guest)
        var settings = withDependencies {
            $0.installTestSpies()
            $0.values = rootTestConstantValues()
        } operation: {
            SettingsFeature.State(
                selection: .init(festivalId: fixture.festival.id, districtId: nil),
                festivals: [fixture.festival],
                userRole: .guest,
                appState: appState
            )
        }
        settings.destination = .login(LoginFeature.State(appState: appState))
        initial.destination = .settings(settings)
        let lastScreen = LastMainScreenUseCaseSpy()
        let store = TestStore(initialState: initial) {
            RootFeature()
        } withDependencies: {
            $0.installTestSpies()
            $0.values = rootTestConstantValues()
            $0[LastMainScreenUseCaseKey.self] = lastScreen
        }
        store.exhaustivity = .off

        await store.send(.destination(.presented(.settings(
            .destination(.presented(.login(.received(.success(.signedIn(.guest))))))
        ))))
        #expect(store.state.launchState == .festival(.guest))
        #expect(store.state.destination?.adminDistrict == nil)
        #expect(store.state.destination?.adminFestival == nil)
        #expect(store.state.alert == .error("管理者としてログインできませんでした"))
        #expect(lastScreen.value == .map)
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

        await store.send(.destination(.presented(.adminFestival(.signOutReceived(.success(.festival(.guest)))))))

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

    @Test("地区管理者の前回画面が地図なら管理画面を開かず地区用の地図を復元する")
    @MainActor
    func districtAdminWithMapHistoryRestoresMapWithoutDashboard() async {
        let fixture = RootFeatureFixture()
        let role = UserRole.district(fixture.district.id)
        let appState = Shared<AppState?>(value: fixture.appState)
        let lastScreen = LastMainScreenUseCaseSpy(value: .map)
        let store = TestStore(initialState: RootFeature.State(appState: appState)) {
            RootFeature()
        } withDependencies: {
            $0.installTestSpies()
            $0[LastMainScreenUseCaseKey.self] = lastScreen
        }
        store.exhaustivity = .off

        await store.send(.launchFinished(.district(role, nil), nil))
        #expect(store.state.launchState == .district(role, nil))
        #expect(store.state.map?.userRole == role)
        #expect(store.state.destination == nil)
        #expect(lastScreen.value == .map)
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

    @Test("地図上の配信位置から町紹介を開く際に地区取得が失敗したら取得理由を提示する")
    @MainActor
    func annotationIntroductionFailureReportsFetchError() async {
        let fixture = RootFeatureFixture()
        let appState = Shared<AppState?>(value: fixture.appState)
        var initial = RootFeature.State(appState: appState)
        initial.$launchState.withLock { $0 = .festival(.guest) }
        initial.map = initial.makeMapState(userRole: .guest)
        let error = AppError.be(.network("district unavailable"))
        let store = TestStore(initialState: initial) {
            RootFeature()
        } withDependencies: {
            $0.installTestSpies()
            $0[FetchDistrictUseCaseKey.self] = RootDistrictFetchFailureSpy(error: error)
        }
        store.exhaustivity = .off
        let entry = FloatEntry(
            floatLocation: FloatLocation(
                id: "float-1", districtId: fixture.district.id,
                coordinate: Coordinate(latitude: 35, longitude: 139)
            ),
            district: fixture.district
        )

        await store.send(.map(.destination(.presented(.locations(.floatTapped(entry)))))) {
            $0.isIntroductionLoading = true
        }
        await store.receive(.introductionPrepared(.failure(error))) {
            $0.isIntroductionLoading = false
            $0.alert = .error(error.message)
        }
        #expect(store.state.sheet == nil)
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
    @Test("起動状態は地図・オンボーディング・エラー表示へ漏れなく変換される")
    func sceneIsDerivedFromLaunchState() {
        var state = RootFeature.State()
        #expect(state.scene == .loading)

        state.$launchState.withLock { $0 = .onboarding }
        #expect(state.scene == .onboarding)

        state.$launchState.withLock { $0 = .festival(.guest) }
        #expect(state.scene == .map)

        state.$launchState.withLock { $0 = .district(.district("district"), "route") }
        #expect(state.scene == .map)

        state.$launchState.withLock { $0 = .festival(.headquarter("festival")) }
        #expect(state.scene == .map)

        state.$launchState.withLock { $0 = .error("offline") }
        #expect(state.scene == .error("offline"))
    }

    @Test("AppStateが無いと地図を作らず、町がある場合は町選択を引き継ぐ")
    func mapStateRespectsAvailableAppState() {
        let empty = RootFeature.State()
        #expect(empty.makeMapState(userRole: .guest) == nil)

        let appState = Shared<AppState?>(value: AppStateFixture.state())
        let state = RootFeature.State(appState: appState)
        let map = state.makeMapState(userRole: .district("district"), currentRouteId: "route")

        #expect(map != nil)
        #expect(map?.selectedContent == .route("district"))
        #expect(map?.userRole == .district("district"))
    }

    @Test("オンボーディングの状態は起動状態とアプリ情報を共有する")
    func onboardingStateSharesLaunchState() {
        let appState = Shared<AppState?>(value: nil)
        var state = RootFeature.State(appState: appState)
        let onboarding = state.makeOnboardingState()

        #expect(onboarding.launchState == .loading)
        state.$launchState.withLock { $0 = .onboarding }
        #expect(onboarding.launchState == .onboarding)
    }

    @Test("起動状態がエラーの場合だけ障害情報をエラー領域に表示する")
    func statusIsClassifiedByLaunchScene() {
        var state = RootFeature.State()
        let status = StatusCheckResult.updateRequired(
            storeURL: URL(string: "https://apps.apple.com/app/id123")!
        )
        state.status = status
        #expect(state.errorStatus == nil)
        #expect(state.normalStatus == status)

        state.$launchState.withLock { $0 = .error("offline") }
        #expect(state.errorStatus == status)
        #expect(state.normalStatus == nil)
        state.$launchState.withLock { $0 = .onboarding }
        #expect(state.errorStatus == nil)
        #expect(state.normalStatus == status)
    }

    @Test("メンテナンス情報のDismissは起動状態と地図を変更しない")
    @MainActor
    func dismissStatusOnlyClearsStatus() async {
        let fixture = RootFeatureFixture()
        var state = RootFeature.State(appState: Shared<AppState?>(value: fixture.appState))
        state.$launchState.withLock { $0 = .festival(.guest) }
        state.map = state.makeMapState(userRole: .guest)
        state.status = .maintenance(message: "maintenance", until: Date(timeIntervalSince1970: 2_000_000_000))
        let store = TestStore(initialState: state) {
            RootFeature()
        } withDependencies: { $0.installTestSpies() }

        await store.send(.statusDismissed) {
            $0.status = nil
        }
        #expect(store.state.launchState == .festival(.guest))
        #expect(store.state.map != nil)
        await store.finish()
    }

    @Test("紹介データの取得失敗後は読み込みを解除してエラー原因を表示する")
    @MainActor
    func failedIntroductionShowsMessage() async {
        let error = AppError.be(.network("offline"))
        var state = RootFeature.State()
        state.isIntroductionLoading = true
        let store = TestStore(initialState: state) {
            RootFeature()
        } withDependencies: { $0.installTestSpies() }

        await store.send(.introductionPrepared(.failure(error))) {
            $0.isIntroductionLoading = false
            $0.alert = AlertFeature.error(error.message)
        }
        #expect(store.state.sheet == nil)
        await store.finish()
    }

    @Test("設定準備が成功しても起動シーンが確定していなければ設定画面を表示しない")
    @MainActor
    func settingsResultIgnoredBeforeLaunchFinishes() async {
        var state = RootFeature.State()
        state.isDestinationLoading = true
        let store = TestStore(initialState: state) {
            RootFeature()
        } withDependencies: { $0.installTestSpies() }

        await store.send(.settingsPrepared(.success(.init(
            festivals: [AppStateFixture.festival()],
            selection: SceneSelection(festivalId: "festival", districtId: nil)
        )))) {
            $0.isDestinationLoading = false
        }
        #expect(store.state.destination == nil)
        await store.finish()
    }

    @Test("緊急ログアウト失敗時は管理画面を残し失敗理由を警告する")
    @MainActor
    func failedEmergencySignOutKeepsCurrentScene() async {
        let fixture = RootFeatureFixture()
        var state = RootFeature.State(appState: Shared<AppState?>(value: fixture.appState))
        state.$launchState.withLock { $0 = .festival(.headquarter("festival")) }
        state.map = state.makeMapState(userRole: .headquarter("festival"))
        state.isEmergencySignOutLoading = true
        let store = TestStore(initialState: state) {
            RootFeature()
        } withDependencies: { $0.installTestSpies() }
        let error = AppError.be(.network("offline"))

        await store.send(.emergencySignOutReceived(.failure(error))) {
            $0.isEmergencySignOutLoading = false
            $0.alert = AlertFeature.error("ログアウトに失敗しました。 \(error.message)")
        }
        #expect(store.state.launchState == .festival(.headquarter("festival")))
        await store.finish()
    }

    @Test("緊急ログアウト成功時は管理者の画面状態と最終画面記録を破棄する")
    @MainActor
    func successfulEmergencySignOutResetsAdminScene() async {
        let fixture = RootFeatureFixture()
        let appState = Shared<AppState?>(value: fixture.appState)
        var state = RootFeature.State(appState: appState)
        state.$launchState.withLock { $0 = .festival(.headquarter("festival")) }
        state.map = state.makeMapState(userRole: .headquarter("festival"))
        state.destination = .adminFestival(.init(fixture.festival, appState: appState))
        state.isEmergencySignOutLoading = true
        let lastScreen = LastMainScreenUseCaseSpy(value: .admin)
        let store = TestStore(initialState: state) {
            RootFeature()
        } withDependencies: {
            $0.installTestSpies()
            $0[LastMainScreenUseCaseKey.self] = lastScreen
        }
        store.exhaustivity = .off

        await store.send(.emergencySignOutReceived(.success(.onboarding)))
        #expect(store.state.launchState == .onboarding)
        #expect(store.state.map == nil)
        #expect(store.state.destination == nil)
        #expect(store.state.onboarding != nil)
        #expect(!store.state.isEmergencySignOutLoading)
        #expect(lastScreen.value == nil)
        await store.finish()
    }

    @Test("起動に失敗したときは中途半端な地図やオンボーディング状態を保持しない")
    @MainActor
    func launchFailureClearsDestinations() async {
        let fixture = RootFeatureFixture()
        let appState = Shared<AppState?>(value: fixture.appState)
        var state = RootFeature.State(appState: appState)
        state.map = state.makeMapState(userRole: .guest)
        let store = TestStore(initialState: state) {
            RootFeature()
        } withDependencies: { $0.installTestSpies() }
        store.exhaustivity = .off

        await store.send(.launchFinished(.error("offline"), nil))
        #expect(store.state.scene == .error("offline"))
        #expect(store.state.map == nil)
        #expect(store.state.onboarding == nil)
        #expect(store.state.destination == nil)
        await store.finish()
    }

    @Test("町シーンのゲスト起動は保存済み管理画面を破棄して地図を復元する")
    @MainActor
    func districtGuestLaunchRestoresMapWithoutAdmin() async {
        let fixture = RootFeatureFixture()
        let lastScreen = LastMainScreenUseCaseSpy(value: .admin)
        let store = TestStore(
            initialState: RootFeature.State(appState: Shared<AppState?>(value: fixture.appState))
        ) {
            RootFeature()
        } withDependencies: {
            $0.installTestSpies()
            $0[LastMainScreenUseCaseKey.self] = lastScreen
        }
        store.exhaustivity = .off

        await store.send(.launchFinished(.district(.guest, nil), nil))
        #expect(store.state.launchState == .district(.guest, nil))
        #expect(store.state.map != nil)
        #expect(store.state.destination == nil)
        #expect(lastScreen.value == nil)
        await store.finish()
    }

    @Test("他の祭典の本部権限では管理画面を開かず地図へフォールバックする")
    @MainActor
    func mismatchedAdminFestivalCannotOpenDashboard() async {
        let fixture = RootFeatureFixture()
        let role = UserRole.headquarter("different-festival")
        let lastScreen = LastMainScreenUseCaseSpy(value: .admin)
        let store = TestStore(
            initialState: RootFeature.State(appState: Shared<AppState?>(value: fixture.appState))
        ) {
            RootFeature()
        } withDependencies: {
            $0.installTestSpies()
            $0[LastMainScreenUseCaseKey.self] = lastScreen
        }
        store.exhaustivity = .off

        await store.send(.launchFinished(.festival(role), nil))
        #expect(store.state.map?.userRole == role)
        #expect(store.state.destination == nil)
        #expect(store.state.alert == .error("情報の取得に失敗しました"))
        #expect(lastScreen.value == .map)
        await store.finish()
    }

    @Test("起動待ち状態への緊急ログアウトでは以前の管理セッションをすべて破棄する")
    @MainActor
    func emergencySignOutToLoadingClearsSession() async {
        let fixture = RootFeatureFixture()
        let appState = Shared<AppState?>(value: fixture.appState)
        var initial = RootFeature.State(appState: appState)
        initial.$launchState.withLock { $0 = .festival(.headquarter(fixture.festival.id)) }
        initial.map = initial.makeMapState(userRole: .headquarter(fixture.festival.id))
        initial.destination = .adminFestival(.init(fixture.festival, appState: appState))
        initial.isEmergencySignOutLoading = true
        let lastScreen = LastMainScreenUseCaseSpy(value: .admin)
        let store = TestStore(initialState: initial) {
            RootFeature()
        } withDependencies: {
            $0.installTestSpies()
            $0[LastMainScreenUseCaseKey.self] = lastScreen
        }
        store.exhaustivity = .off

        await store.send(.emergencySignOutReceived(.success(.loading)))
        #expect(store.state.launchState == .loading)
        #expect(store.state.map == nil)
        #expect(store.state.onboarding == nil)
        #expect(store.state.destination == nil)
        #expect(!store.state.isEmergencySignOutLoading)
        #expect(lastScreen.value == nil)
        await store.finish()
    }

    @Test("管理画面を閉じたら次回の初期画面を地図にする")
    @MainActor
    func dismissingAdminRecordsMapAsLastScreen() async {
        let fixture = RootFeatureFixture()
        let role = UserRole.headquarter(fixture.festival.id)
        let appState = Shared<AppState?>(value: fixture.appState)
        var initial = RootFeature.State(appState: appState)
        initial.$launchState.withLock { $0 = .festival(role) }
        initial.destination = .adminFestival(.init(fixture.festival, appState: appState))
        let lastScreen = LastMainScreenUseCaseSpy(value: .admin)
        let store = TestStore(initialState: initial) {
            RootFeature()
        } withDependencies: {
            $0.installTestSpies()
            $0[LastMainScreenUseCaseKey.self] = lastScreen
        }
        store.exhaustivity = .off

        await store.send(.destination(.dismiss))
        #expect(lastScreen.value == .map)
        await store.finish()
    }

    @Test("緊急ログアウトの操作はUseCaseを一度呼び出し成功時にゲスト状態へ切り替える")
    @MainActor
    func emergencySignOutButtonInvokesUseCase() async {
        let fixture = RootFeatureFixture()
        let appState = Shared<AppState?>(value: fixture.appState)
        var initial = RootFeature.State(appState: appState)
        let role = UserRole.headquarter(fixture.festival.id)
        initial.$launchState.withLock { $0 = .festival(role) }
        initial.map = initial.makeMapState(userRole: role)
        let spy = RootSignOutSpy(result: .success(.festival(.guest)))
        let lastScreen = LastMainScreenUseCaseSpy(value: .admin)
        let store = TestStore(initialState: initial) {
            RootFeature()
        } withDependencies: {
            $0.installTestSpies()
            $0[SignOutUseCaseKey.self] = spy
            $0[LastMainScreenUseCaseKey.self] = lastScreen
        }
        store.exhaustivity = .off

        await store.send(.map(.delegate(.emergencySignOutTapped)))
        await store.receive(.emergencySignOutReceived(.success(.festival(.guest))))
        #expect(await spy.calls == 1)
        #expect(store.state.launchState == .festival(.guest))
        #expect(!store.state.isEmergencySignOutLoading)
        #expect(lastScreen.value == nil)
        await store.finish()
    }

    @Test("緊急ログアウト中の連打は二重にUseCaseを起動しない")
    @MainActor
    func repeatedEmergencySignOutWhileLoadingIsIgnored() async {
        let fixture = RootFeatureFixture()
        var initial = RootFeature.State(appState: Shared<AppState?>(value: fixture.appState))
        initial.$launchState.withLock { $0 = .festival(.guest) }
        initial.map = initial.makeMapState(userRole: .guest)
        initial.isEmergencySignOutLoading = true
        let spy = RootSignOutSpy(result: .success(.onboarding))
        let store = TestStore(initialState: initial) {
            RootFeature()
        } withDependencies: {
            $0.installTestSpies()
            $0[SignOutUseCaseKey.self] = spy
        }
        store.exhaustivity = .off

        await store.send(.map(.delegate(.emergencySignOutTapped)))
        #expect(await spy.calls == 0)
        #expect(store.state.isEmergencySignOutLoading)
        await store.finish()
    }

    @Test("現在地へ戻る操作は開いている紹介シートを閉じ地図の表示対象を現在地に戻す")
    @MainActor
    func currentLocationDismissesSheetAndSelectsLocations() async {
        let fixture = RootFeatureFixture()
        let appState = Shared<AppState?>(value: fixture.appState)
        var initial = RootFeature.State(appState: appState)
        initial.$launchState.withLock { $0 = .district(.guest, nil) }
        initial.map = PublicMapFeature.State(
            festival: fixture.festival,
            district: fixture.district,
            routeId: nil,
            userRole: .guest,
            appState: appState
        )
        initial.sheet = .festival(.init(fixture.festival, appState: appState))
        let store = TestStore(initialState: initial) {
            RootFeature()
        } withDependencies: { $0.installTestSpies() }
        store.exhaustivity = .off

        await store.send(.currentLocationTapped)
        await store.receive(.map(.contentSelected(.locations)))
        #expect(store.state.sheet == nil)
        #expect(store.state.map?.selectedContent == .locations)
        await store.finish()
    }

    @Test("設定画面の準備中は再タップしても二重の取得処理を開始しない")
    @MainActor
    func settingsTapWhileLoadingIsIgnored() async {
        let fixture = RootFeatureFixture()
        var initial = RootFeature.State(appState: Shared<AppState?>(value: fixture.appState))
        initial.$launchState.withLock { $0 = .festival(.guest) }
        initial.map = initial.makeMapState(userRole: .guest)
        initial.isDestinationLoading = true
        let spy = FailingFestivalListUseCaseSpy()
        let store = TestStore(initialState: initial) {
            RootFeature()
        } withDependencies: {
            $0.installTestSpies()
            $0[FetchFestivalListUseCaseKey.self] = spy
        }
        store.exhaustivity = .off

        await store.send(.map(.delegate(.settingsTapped)))
        #expect(await spy.fetchCallCount() == 0)
        #expect(store.state.isDestinationLoading)
        await store.finish()
    }

    @Test("紹介画面の準備中は同じ操作を繰り返しても取得を開始しない")
    @MainActor
    func introductionTapWhileLoadingIsIgnored() async {
        let fixture = RootFeatureFixture()
        var initial = RootFeature.State(appState: Shared<AppState?>(value: fixture.appState))
        initial.$launchState.withLock { $0 = .festival(.guest) }
        initial.map = initial.makeMapState(userRole: .guest)
        initial.isIntroductionLoading = true
        let spy = FetchDistrictUseCaseSpy()
        let store = TestStore(initialState: initial) {
            RootFeature()
        } withDependencies: {
            $0.installTestSpies()
            $0[FetchDistrictUseCaseKey.self] = spy
        }
        store.exhaustivity = .off

        await store.send(.map(.delegate(.introductionTapped)))
        #expect(await spy.requestedIDs.isEmpty)
        #expect(store.state.isIntroductionLoading)
        await store.finish()
    }

    @Test("設定画面で管理者からゲストへ切り替えると地図と保存済み管理画面を更新する")
    @MainActor
    func guestSceneSelectionClosesAdminDestination() async {
        let fixture = RootFeatureFixture()
        let appState = Shared<AppState?>(value: fixture.appState)
        let role = UserRole.headquarter(fixture.festival.id)
        var initial = RootFeature.State(appState: appState)
        initial.$launchState.withLock { $0 = .festival(role) }
        initial.map = initial.makeMapState(userRole: role)
        initial.destination = .settings(withDependencies {
            $0.installTestSpies()
            $0.values = rootTestConstantValues()
        } operation: {
            SettingsFeature.State(
                selection: .init(festivalId: fixture.festival.id, districtId: nil),
                festivals: [fixture.festival],
                userRole: role,
                appState: appState
            )
        })
        let lastScreen = LastMainScreenUseCaseSpy(value: .admin)
        let store = TestStore(initialState: initial) {
            RootFeature()
        } withDependencies: {
            $0.installTestSpies()
            $0.values = rootTestConstantValues()
            $0[LastMainScreenUseCaseKey.self] = lastScreen
        }
        store.exhaustivity = .off

        await store.send(.destination(.presented(.settings(
            .delegate(.sceneSelectionChanged(.guest, nil))
        ))))
        #expect(store.state.launchState == .festival(.guest))
        #expect(store.state.map?.userRole == .guest)
        #expect(store.state.destination == nil)
        #expect(lastScreen.value == nil)
        await store.finish()
    }

    @Test("管理者の参加設定変更はゲスト地図と現在の設定画面を同時に作り直す")
    @MainActor
    func participationChangeRebuildsGuestSettings() async {
        let fixture = RootFeatureFixture()
        let appState = Shared<AppState?>(value: fixture.appState)
        let role = UserRole.headquarter(fixture.festival.id)
        let selection = SceneSelection(festivalId: fixture.festival.id, districtId: nil)
        let preparation = SettingsPreparation(
            festivals: [fixture.festival], selection: selection
        )
        var initial = RootFeature.State(appState: appState)
        initial.$launchState.withLock { $0 = .festival(role) }
        initial.map = initial.makeMapState(userRole: role)
        initial.destination = .settings(withDependencies {
            $0.installTestSpies()
            $0.values = rootTestConstantValues()
        } operation: {
            SettingsFeature.State(
                selection: selection, festivals: [fixture.festival],
                userRole: role, appState: appState
            )
        })
        let lastScreen = LastMainScreenUseCaseSpy(value: .admin)
        let store = TestStore(initialState: initial) {
            RootFeature()
        } withDependencies: {
            $0.installTestSpies()
            $0.values = rootTestConstantValues()
            $0[LastMainScreenUseCaseKey.self] = lastScreen
        }
        store.exhaustivity = .off

        await store.send(.destination(.presented(.settings(
            .delegate(.participationChanged(preparation))
        ))))
        #expect(store.state.launchState == .festival(.guest))
        #expect(store.state.map?.userRole == .guest)
        #expect(store.state.destination?.settings?.userRole == .guest)
        #expect(lastScreen.value == nil)
        await store.finish()
    }

    @Test("起動済みのRootへ再びlaunchが届いても起動UseCaseを重複実行しない")
    @MainActor
    func duplicateLaunchDoesNotCallBackend() async {
        var initial = RootFeature.State()
        initial.didLaunch = true
        let spy = LaunchSceneUseCaseSpy()
        let store = TestStore(initialState: initial) {
            RootFeature()
        } withDependencies: {
            $0.installTestSpies()
            $0[LaunchSceneUseCaseKey.self] = spy
        }
        await store.send(.launch)
        #expect(await spy.calls == 0)
        await store.finish()
    }

    @Test("ゲストとして続行するとOnboardingを閉じて祭典地図へ切り替える")
    @MainActor
    func guestOnboardingCompletionOpensMap() async {
        let fixture = RootFeatureFixture()
        let appState = Shared<AppState?>(value: fixture.appState)
        var initial = RootFeature.State(appState: appState)
        initial.$launchState.withLock { $0 = .festival(.guest) }
        initial.onboarding = initial.makeOnboardingState()
        let store = TestStore(initialState: initial) {
            RootFeature()
        } withDependencies: { $0.installTestSpies() }
        store.exhaustivity = .off

        await store.send(.onboarding(.delegate(.continueAsGuest)))
        #expect(store.state.onboarding == nil)
        #expect(store.state.map?.userRole == .guest)
        #expect(store.state.scene == .map)
        await store.finish()
    }

    @Test("存在しない地区への経路切替要求は紹介シートを閉じ、地図側で選択だけ保持する")
    @MainActor
    func unknownDistrictRouteTapDoesNotStartLoad() async {
        let fixture = RootFeatureFixture()
        let appState = Shared<AppState?>(value: fixture.appState)
        var initial = RootFeature.State(appState: appState)
        initial.$launchState.withLock { $0 = .festival(.guest) }
        initial.map = initial.makeMapState(userRole: .guest)
        initial.sheet = .festival(FestivalInfoFeature.State(
            fixture.festival, appState: appState
        ))
        let store = TestStore(initialState: initial) {
            RootFeature()
        } withDependencies: { $0.installTestSpies() }
        store.exhaustivity = .off

        await store.send(.routeTapped("unknown-district"))
        await store.receive(.map(.contentSelected(.route("unknown-district"))))
        #expect(store.state.sheet == nil)
        #expect(store.state.map?.selectedContent == .route("unknown-district"))
        await store.finish()
    }


    @Test("地区管理者として復元したが権限に対応する町が無い場合は管理画面を開かない")
    @MainActor
    func staleDistrictAdminRoleFallsBackToMap() async {
        let fixture = RootFeatureFixture()
        let lastScreen = LastMainScreenUseCaseSpy(value: .admin)
        let store = TestStore(initialState: RootFeature.State(
            appState: Shared<AppState?>(value: fixture.appState)
        )) {
            RootFeature()
        } withDependencies: {
            $0.installTestSpies()
            $0[LastMainScreenUseCaseKey.self] = lastScreen
        }
        store.exhaustivity = .off

        await store.send(.launchFinished(.district(.district("deleted-district"), nil), nil))
        #expect(store.state.map != nil)
        #expect(store.state.destination == nil)
        #expect(store.state.alert != nil)
        #expect(lastScreen.value == .map)
        await store.finish()
    }

    @Test("Onboardingで町を選択すると指定ルートを保持して地区地図へ移行する")
    @MainActor
    func onboardingDistrictChoiceClosesOnboarding() async {
        let fixture = RootFeatureFixture()
        let appState = Shared<AppState?>(value: fixture.appState)
        var initial = RootFeature.State(appState: appState)
        initial.$launchState.withLock { $0 = .district(.guest, nil) }
        initial.onboarding = initial.makeOnboardingState()
        let store = TestStore(initialState: initial) {
            RootFeature()
        } withDependencies: { $0.installTestSpies() }
        store.exhaustivity = .off

        await store.send(.onboarding(.delegate(.districtSelected("selected-route"))))
        #expect(store.state.onboarding == nil)
        #expect(store.state.map?.userRole == .guest)
        #expect(store.state.scene == .map)
        await store.finish()
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
                year: 2026,
                districts: [district],
                periods: [],
                locations: [],
                checkpoints: [],
                hazardSections: []
            ),
        )
    }

    @Test("地区管理者の画面でログアウトした時もRootが管理者状態と最終画面記録を破棄する")
    @MainActor
    func districtAdminSignOutResetsNavigation() async {
        let fixture = RootFeatureFixture()
        let appState = Shared<AppState?>(value: fixture.appState)
        let role = UserRole.district(fixture.district.id)
        var initial = RootFeature.State(appState: appState)
        initial.$launchState.withLock { $0 = .district(role, nil) }
        initial.map = initial.makeMapState(userRole: role)
        initial.destination = .adminDistrict(.init(fixture.district, appState: appState))
        let lastScreen = LastMainScreenUseCaseSpy(value: .admin)
        let store = TestStore(initialState: initial) {
            RootFeature()
        } withDependencies: {
            $0.installTestSpies()
            $0[LastMainScreenUseCaseKey.self] = lastScreen
        }
        store.exhaustivity = .off

        await store.send(.destination(.presented(.adminDistrict(
            .signOutReceived(.success(.festival(.guest)))
        ))))
        #expect(store.state.launchState == .festival(.guest))
        #expect(store.state.map?.userRole == .guest)
        #expect(store.state.destination == nil)
        #expect(lastScreen.value == nil)
        await store.finish()
    }

    @Test("エラー通知をスワイプで閉じた場合もRootの起動状態は変わらない")
    @MainActor
    func dismissingAlertWithoutButtonPreservesScene() async {
        let fixture = RootFeatureFixture()
        var initial = RootFeature.State(appState: Shared<AppState?>(value: fixture.appState))
        initial.$launchState.withLock { $0 = .festival(.guest) }
        initial.map = initial.makeMapState(userRole: .guest)
        initial.alert = .error("接続が切断されました")
        let store = TestStore(initialState: initial) {
            RootFeature()
        } withDependencies: { $0.installTestSpies() }
        store.exhaustivity = .off

        await store.send(.alert(.dismiss))
        #expect(store.state.alert == nil)
        #expect(store.state.launchState == .festival(.guest))
        #expect(store.state.map != nil)
        await store.finish()
    }

    @Test("Rootのエラー通知を閉じる操作は現在の画面状態を変えずAlertだけ破棄する")
    @MainActor
    func rootAlertAcknowledgementDoesNotChangeScene() async {
        let fixture = RootFeatureFixture()
        var initial = RootFeature.State(appState: Shared<AppState?>(value: fixture.appState))
        initial.$launchState.withLock { $0 = .festival(.guest) }
        initial.map = initial.makeMapState(userRole: .guest)
        initial.alert = .error("サーバーに接続できませんでした")
        let store = TestStore(initialState: initial) {
            RootFeature()
        } withDependencies: { $0.installTestSpies() }
        store.exhaustivity = .off

        await store.send(.alert(.presented(.okTapped)))
        #expect(store.state.alert == nil)
        #expect(store.state.launchState == .festival(.guest))
        #expect(store.state.map != nil)
        await store.finish()
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
        publicMapBannerAdUnitId: nil,
        storeCreditProductId500: nil,
        storeCreditProductId1000: nil
    )
}



private actor RootDistrictFetchFailureSpy: FetchDistrictUseCaseProtocol {
    let error: AppError

    init(error: AppError) { self.error = error }

    func callAsFunction(districtId: District.ID) async throws -> DistrictPack {
        throw error
    }
}

private actor RootLaunchSuccessSpy: LaunchSceneUseCaseProtocol {
    let result: LaunchState
    private(set) var calls = 0

    init(result: LaunchState) { self.result = result }

    func callAsFunction(appState: Shared<AppState?>?) async -> (LaunchState, StatusCheckResult?) {
        calls += 1
        return (result, nil)
    }
}

private actor RootSignOutSpy: SignOutUseCaseProtocol {
    let result: Result<LaunchState, AppError>
    private(set) var calls = 0

    init(result: Result<LaunchState, AppError>) { self.result = result }

    func callAsFunction(appState: Shared<AppState?>) async throws -> LaunchState {
        calls += 1
        return try result.get()
    }
}
