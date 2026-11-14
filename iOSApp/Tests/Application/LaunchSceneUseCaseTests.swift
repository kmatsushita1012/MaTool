import ComposableArchitecture
import Dependencies
import Shared
import Testing
@testable import iOSApp

struct LaunchSceneUseCaseTests {
    private func festivalPack() -> LaunchFestivalPack {
        LaunchFestivalPack(
            festival: AppStateFixture.festival(),
            districts: [AppStateFixture.district()],
            periods: [AppStateFixture.period()],
            locations: [], checkpoints: [], hazardSections: []
        )
    }

    private func districtPack() -> LaunchDistrictPack {
        let route = AppStateFixture.route()
        return LaunchDistrictPack(
            performances: [], routes: [route], points: [],
            passages: [], currentRouteId: route.id
        )
    }

    @Test("祭典未選択でも認証状態を読み取ってOnboardingを返す")
    func noSelectionOpensOnboarding() async {
        let initialization = AuthProviderInitializeSpy()
        let roleLookup = AuthProviderRoleLookupSpy(role: .guest)
        var auth = AuthProviderSpy().client
        auth.initialize = { initialization.record() }
        auth.getUserRole = { await roleLookup.call() }
        let defaults = DefaultUserDefaultsSpy()
        let state = Shared<AppState?>(value: AppStateFixture.state())
        let useCase = withDependencies {
            $0.installTestSpies()
            $0.authProvider = auth
            $0[UserDefaltsManagerKey.self] = defaults
            $0[AppStatusClientKey.self] = AppStatusClientSpy()
        } operation: { LaunchSceneUseCase() }

        let (launchState, status) = await useCase(appState: state)

        #expect(launchState == .onboarding)
        #expect(status == nil)
        #expect(initialization.callCount == 1)
        #expect(await roleLookup.callCount() == 1)
        #expect(state.wrappedValue == nil)
    }

    @Test("祭典選択済みでは祭典パックを取得してAppStateを構築する")
    func festivalSelectionRestoresPublicMap() async {
        var auth = AuthProviderSpy().client
        auth.initialize = {}
        auth.getUserRole = { .guest }
        let defaults = DefaultUserDefaultsSpy(festivalId: "festival")
        let fetcher = SignInSceneDataFetcherSpy(
            festivalPack: festivalPack(), districtPack: districtPack()
        )
        let state = Shared<AppState?>(value: nil)
        let useCase = withDependencies {
            $0.installTestSpies()
            $0.authProvider = auth
            $0[UserDefaltsManagerKey.self] = defaults
            $0[SceneDataFetcherKey.self] = fetcher
            $0[AppStatusClientKey.self] = AppStatusClientSpy()
        } operation: { LaunchSceneUseCase() }

        let (launchState, _) = await useCase(appState: state)

        #expect(launchState == .festival(.guest))
        #expect(state.wrappedValue?.festivalState.festival.id == "festival")
        #expect(state.wrappedValue?.districtState == nil)
        #expect(await fetcher.requestedResources() == ["festival"])
    }

    @Test("既定地区が存在すると祭典と地区パックから選択ルートを復元する")
    func districtSelectionRestoresCurrentRoute() async {
        var auth = AuthProviderSpy().client
        auth.initialize = {}
        auth.getUserRole = { .district("district") }
        let defaults = DefaultUserDefaultsSpy(festivalId: "festival", districtId: "district")
        let fetcher = SignInSceneDataFetcherSpy(
            festivalPack: festivalPack(), districtPack: districtPack()
        )
        let state = Shared<AppState?>(value: nil)
        let useCase = withDependencies {
            $0.installTestSpies()
            $0.authProvider = auth
            $0[UserDefaltsManagerKey.self] = defaults
            $0[SceneDataFetcherKey.self] = fetcher
            $0[AppStatusClientKey.self] = AppStatusClientSpy()
        } operation: { LaunchSceneUseCase() }

        let (launchState, _) = await useCase(appState: state)

        #expect(launchState == .district(.district("district"), "route"))
        #expect(state.wrappedValue?.selectedDistrict?.id == "district")
        #expect(state.wrappedValue?.routeState?.route.id == "route")
        #expect(Set(await fetcher.requestedResources()) == Set(["festival", "district"]))
    }

    @Test("認証状態の取得に失敗してもゲストとして既定祭典を開ける")
    func roleLookupFailureFallsBackToGuest() async {
        let signout = SignInSignOutSpy()
        var auth = AuthProviderSpy().client
        auth.initialize = {}
        auth.getUserRole = { throw LaunchSceneFailure.unavailable }
        auth.signOut = { await signout.record() }
        let fetcher = SignInSceneDataFetcherSpy(
            festivalPack: festivalPack(), districtPack: districtPack()
        )
        let useCase = withDependencies {
            $0.installTestSpies()
            $0.authProvider = auth
            $0[UserDefaltsManagerKey.self] = DefaultUserDefaultsSpy(festivalId: "festival")
            $0[SceneDataFetcherKey.self] = fetcher
            $0[AppStatusClientKey.self] = AppStatusClientSpy()
        } operation: { LaunchSceneUseCase() }

        let (result, _) = await useCase(appState: nil)

        #expect(result == .festival(.guest))
        #expect(await signout.count() == 1)
    }

    @Test("認証の初期化に失敗するとAppStateを消してエラー状態を返す")
    func initializationFailureIsVisible() async {
        var auth = AuthProviderSpy().client
        auth.initialize = { throw LaunchSceneFailure.unavailable }
        let original = AppStateFixture.state()
        let state = Shared<AppState?>(value: original)
        let useCase = withDependencies {
            $0.installTestSpies()
            $0.authProvider = auth
            $0[UserDefaltsManagerKey.self] = DefaultUserDefaultsSpy(festivalId: "festival")
            $0[AppStatusClientKey.self] = AppStatusClientSpy()
        } operation: { LaunchSceneUseCase() }

        let (result, _) = await useCase(appState: state)

        if case .error(let message) = result {
            #expect(!message.isEmpty)
        } else {
            Issue.record("認証初期化失敗でエラー画面になりませんでした")
        }
        #expect(state.wrappedValue == nil)
    }

    @Test("祭典が削除済みの場合は既定選択を消してOnboardingへ戻す")
    func notFoundResetsSelection() async {
        var auth = AuthProviderSpy().client
        auth.initialize = {}
        auth.getUserRole = { .guest }
        let defaults = DefaultUserDefaultsSpy(festivalId: "festival", districtId: "district")
        let fetcher = MissingSceneDataFetcherSpy()
        let useCase = withDependencies {
            $0.installTestSpies()
            $0.authProvider = auth
            $0[UserDefaltsManagerKey.self] = defaults
            $0[SceneDataFetcherKey.self] = fetcher
            $0[AppStatusClientKey.self] = AppStatusClientSpy()
        } operation: { LaunchSceneUseCase() }

        let (result, _) = await useCase(appState: nil)

        #expect(result == .onboarding)
        #expect(defaults.defaultFestivalId == nil)
        #expect(defaults.defaultDistrictId == nil)
    }
}

private enum LaunchSceneFailure: Swift.Error {
    case unavailable
}
