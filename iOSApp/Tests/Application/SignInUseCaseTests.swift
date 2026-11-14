import ComposableArchitecture
import Dependencies
import Shared
import Testing
@testable import iOSApp

struct SignInUseCaseTests {
    @Test("認証成功後に管理者データを取得してからログイン結果を返す")
    func loadsAdminSessionBeforeReturningSuccess() async throws {
        let festival = Festival(
            id: "festival",
            name: "Festival",
            subname: "Festival",
            base: Coordinate(latitude: 35, longitude: 139)
        )
        let district = District(id: "district", name: "District", festivalId: festival.id)
        let festivalPack = LaunchFestivalPack(
            festival: festival,
            districts: [district],
            periods: [],
            locations: [],
            checkpoints: [],
            hazardSections: []
        )
        let districtPack = LaunchDistrictPack(
            performances: [],
            routes: [],
            points: [],
            passages: [],
            currentRouteId: nil
        )
        var provider = AuthProviderSpy().client
        provider.signOut = {}
        provider.signIn = { _, _ in .success }
        provider.getUserRole = { .district(district.id) }
        let fetcher = SignInSceneDataFetcherSpy(
            festivalPack: festivalPack,
            districtPack: districtPack
        )
        let appState = Shared<AppState?>(value: nil)
        let useCase = withDependencies {
            $0.installTestSpies()
            $0.authProvider = provider
            $0[SceneDataFetcherKey.self] = fetcher
            $0[UserDefaltsManagerKey.self] = DefaultUserDefaultsSpy()
        } operation: {
            SignInUseCase()
        }

        let result = try await useCase(username: "admin", password: "secret", appState: appState)

        #expect(result == .signedIn(.district(district.id)))
        #expect(appState.wrappedValue?.festivalState.festival.id == festival.id)
        #expect(appState.wrappedValue?.selectedDistrict?.id == district.id)
        #expect(await fetcher.requestedResources().sorted() == ["district", "festival"])
    }

    @Test("認証後のロール取得に失敗したらサインアウトしてエラーを返す")
    func roleLookupFailureSignsOutAndPropagatesError() async {
        let signOutSpy = SignInSignOutSpy()
        var provider = AuthProviderSpy().client
        provider.signOut = { await signOutSpy.record() }
        provider.signIn = { _, _ in .success }
        provider.getUserRole = { throw SignInTestError.roleLookup }
        let useCase = withDependencies {
            $0.installTestSpies()
            $0.authProvider = provider
            $0[UserDefaltsManagerKey.self] = DefaultUserDefaultsSpy()
        } operation: {
            SignInUseCase()
        }

        do {
            _ = try await useCase(username: "admin", password: "secret", appState: Shared(value: nil))
            Issue.record("Role取得エラーを返していません")
        } catch let error as SignInTestError {
            #expect(error == .roleLookup)
        } catch {
            Issue.record("想定外のエラー: \(error)")
        }

        #expect(await signOutSpy.count() == 2)
    }
    @Test("初回ログインでパスワード更新が要求された場合は管理者データを取得しない")
    func newPasswordChallengeDoesNotLoadAdminData() async throws {
        let signout = SignInSignOutSpy()
        var auth = AuthProviderSpy().client
        auth.signOut = { await signout.record() }
        auth.signIn = { _, _ in .newPasswordRequired }
        let state = Shared<AppState?>(value: AppStateFixture.state())
        let useCase = withDependencies {
            $0.installTestSpies()
            $0.authProvider = auth
        } operation: { SignInUseCase() }

        let result = try await useCase(
            username: "user", password: "temporary", appState: state
        )

        #expect(result == .newPasswordRequired)
        #expect(state.wrappedValue == nil)
        #expect(await signout.count() == 1)
    }

    @Test("ログインの認証失敗は古い画面状態を消去しエラーを伝える")
    func signInFailureDoesNotRestoreStaleSession() async {
        let signout = SignInSignOutSpy()
        var auth = AuthProviderSpy().client
        auth.signOut = { await signout.record() }
        auth.signIn = { _, _ in throw SignInTestError.roleLookup }
        let state = Shared<AppState?>(value: AppStateFixture.state())
        let defaults = DefaultUserDefaultsSpy(festivalId: "festival")
        let useCase = withDependencies {
            $0.installTestSpies()
            $0.authProvider = auth
            $0[UserDefaltsManagerKey.self] = defaults
        } operation: { SignInUseCase() }

        await #expect(throws: SignInTestError.roleLookup) {
            try await useCase(username: "user", password: "invalid", appState: state)
        }
        #expect(state.wrappedValue == nil)
        #expect(defaults.defaultFestivalId == "festival")
        #expect(await signout.count() == 1)
    }

    @Test("古いセッションのログアウト失敗は新しいログインを妨げない")
    func staleSignoutFailureIsIgnoredBeforeLogin() async throws {
        var auth = AuthProviderSpy().client
        auth.signOut = { throw SignInTestError.roleLookup }
        auth.signIn = { _, _ in .success }
        auth.getUserRole = { .guest }
        let useCase = withDependencies {
            $0.installTestSpies()
            $0.authProvider = auth
        } operation: { SignInUseCase() }

        let result = try await useCase(username: "guest", password: "pw", appState: nil)

        #expect(result == .signedIn(.guest))
    }

    @Test("本部管理者のログイン成功で祭典情報を再取得し既定地区を解除する")
    func headquarterSignInUpdatesFestivalSelection() async throws {
        let festival = AppStateFixture.festival()
        let festivalPack = LaunchFestivalPack(
            festival: festival, districts: [AppStateFixture.district()],
            periods: [], locations: [], checkpoints: [], hazardSections: []
        )
        let districtPack = LaunchDistrictPack(
            performances: [], routes: [], points: [], passages: [], currentRouteId: nil
        )
        let fetcher = SignInSceneDataFetcherSpy(
            festivalPack: festivalPack, districtPack: districtPack
        )
        let defaults = DefaultUserDefaultsSpy(festivalId: "other", districtId: "old")
        var auth = AuthProviderSpy().client
        auth.signOut = {}
        auth.signIn = { _, _ in .success }
        auth.getUserRole = { .headquarter("festival") }
        let state = Shared<AppState?>(value: nil)
        let useCase = withDependencies {
            $0.installTestSpies()
            $0.authProvider = auth
            $0[UserDefaltsManagerKey.self] = defaults
            $0[SceneDataFetcherKey.self] = fetcher
        } operation: { SignInUseCase() }

        let result = try await useCase(
            username: "admin", password: "pass", appState: state
        )

        #expect(result == .signedIn(.headquarter("festival")))
        #expect(state.wrappedValue?.festivalState.festival.id == "festival")
        #expect(state.wrappedValue?.districtState == nil)
        #expect(defaults.defaultFestivalId == "festival")
        #expect(defaults.defaultDistrictId == nil)
        #expect(await fetcher.requestedResources() == ["festival"])
    }

    @Test("ロール取得に成功してゲストであれば管理者のデータを取得しない")
    func guestLoginSkipsAdminFetch() async throws {
        var auth = AuthProviderSpy().client
        auth.signOut = {}
        auth.signIn = { _, _ in .success }
        auth.getUserRole = { .guest }
        let state = Shared<AppState?>(value: nil)
        let defaults = DefaultUserDefaultsSpy()
        let useCase = withDependencies {
            $0.installTestSpies()
            $0.authProvider = auth
            $0[UserDefaltsManagerKey.self] = defaults
        } operation: { SignInUseCase() }

        let result = try await useCase(
            username: "guest", password: "pass", appState: state
        )

        #expect(result == .signedIn(.guest))
        #expect(state.wrappedValue == nil)
        #expect(defaults.defaultFestivalId == nil)
        #expect(defaults.defaultDistrictId == nil)
    }

}

private enum SignInTestError: Error, Equatable {
    case roleLookup
}
