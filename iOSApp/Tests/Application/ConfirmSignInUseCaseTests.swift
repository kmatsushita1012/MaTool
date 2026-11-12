import ComposableArchitecture
import Dependencies
import Shared
import Testing
@testable import iOSApp

struct ConfirmSignInUseCaseTests {
    private func festivalPack() -> LaunchFestivalPack {
        LaunchFestivalPack(
            festival: AppStateFixture.festival(),
            districts: [AppStateFixture.district()],
            periods: [], locations: [], checkpoints: [], hazardSections: []
        )
    }

    private func districtPack() -> LaunchDistrictPack {
        let route = AppStateFixture.route()
        return LaunchDistrictPack(
            performances: [], routes: [route],
            points: [], passages: [], currentRouteId: route.id
        )
    }

    @Test("本部の確認認証は祭典データを構築し、既定地区を解除する")
    func headquarterConfirmationBuildsFestivalSession() async throws {
        let defaults = DefaultUserDefaultsSpy(festivalId: "previous", districtId: "district")
        let fetcher = SignInSceneDataFetcherSpy(festivalPack: festivalPack(), districtPack: districtPack())
        var auth = AuthProviderSpy().client
        auth.confirmSignIn = { _ in }
        auth.getUserRole = { .headquarter("festival") }
        let state = Shared<AppState?>(value: AppStateFixture.state())
        let useCase = withDependencies {
            $0.installTestSpies()
            $0.authProvider = auth
            $0[SceneDataFetcherKey.self] = fetcher
            $0[UserDefaltsManagerKey.self] = defaults
        } operation: { ConfirmSignInUseCase() }

        let role = try await useCase(password: "ValidPass123", appState: state)

        #expect(role == .headquarter("festival"))
        #expect(state.wrappedValue?.festivalState.festival.id == "festival")
        #expect(state.wrappedValue?.districtState == nil)
        #expect(defaults.defaultFestivalId == "festival")
        #expect(defaults.defaultDistrictId == nil)
        #expect(await fetcher.requestedResources() == ["festival"])
    }

    @Test("地区管理者の確認認証は祭典と地区のデータ両方を構築する")
    func districtConfirmationBuildsDistrictSession() async throws {
        let defaults = DefaultUserDefaultsSpy()
        let fetcher = SignInSceneDataFetcherSpy(festivalPack: festivalPack(), districtPack: districtPack())
        var auth = AuthProviderSpy().client
        auth.confirmSignIn = { _ in }
        auth.getUserRole = { .district("district") }
        let state = Shared<AppState?>(value: nil)
        let useCase = withDependencies {
            $0.installTestSpies()
            $0.authProvider = auth
            $0[SceneDataFetcherKey.self] = fetcher
            $0[UserDefaltsManagerKey.self] = defaults
        } operation: { ConfirmSignInUseCase() }

        let role = try await useCase(password: "ValidPass123", appState: state)

        #expect(role == .district("district"))
        #expect(state.wrappedValue?.selectedDistrict?.id == "district")
        #expect(state.wrappedValue?.routeState?.route.id == "route")
        #expect(defaults.defaultFestivalId == "festival")
        #expect(defaults.defaultDistrictId == "district")
        #expect(Set(await fetcher.requestedResources()) == Set(["district", "festival"]))
    }

    @Test("ゲストのロールでは管理者用の起動データを取得しない")
    func guestRoleReturnsGuestWithoutAdminData() async throws {
        let fetcher = SignInSceneDataFetcherSpy(festivalPack: festivalPack(), districtPack: districtPack())
        var auth = AuthProviderSpy().client
        auth.confirmSignIn = { _ in }
        auth.getUserRole = { .guest }
        let state = Shared<AppState?>(value: AppStateFixture.state())
        let useCase = withDependencies {
            $0.installTestSpies()
            $0.authProvider = auth
            $0[SceneDataFetcherKey.self] = fetcher
        } operation: { ConfirmSignInUseCase() }

        #expect(try await useCase(password: "ValidPass123", appState: state) == .guest)
        #expect(state.wrappedValue == nil)
        #expect(await fetcher.requestedResources().isEmpty)
    }

    @Test("認証確認失敗ではサインアウトを実行し、エラーを伝播する")
    func invalidCodeSignsOutAndFails() async {
        let signout = SignInSignOutSpy()
        var auth = AuthProviderSpy().client
        auth.confirmSignIn = { _ in throw ConfirmSignInFailure.denied }
        auth.signOut = { await signout.record() }
        let state = Shared<AppState?>(value: AppStateFixture.state())
        let useCase = withDependencies {
            $0.installTestSpies()
            $0.authProvider = auth
        } operation: { ConfirmSignInUseCase() }

        await #expect(throws: ConfirmSignInFailure.denied) {
            try await useCase(password: "invalid", appState: state)
        }
        #expect(await signout.count() == 1)
        #expect(state.wrappedValue == nil)
    }

    @Test("権限取得失敗でもサインアウトしてエラーを返す")
    func roleLookupFailureSignsOut() async {
        let signout = SignInSignOutSpy()
        var auth = AuthProviderSpy().client
        auth.confirmSignIn = { _ in }
        auth.getUserRole = { throw ConfirmSignInFailure.denied }
        auth.signOut = { await signout.record() }
        let useCase = withDependencies {
            $0.installTestSpies()
            $0.authProvider = auth
        } operation: { ConfirmSignInUseCase() }

        await #expect(throws: ConfirmSignInFailure.denied) {
            try await useCase(password: "ValidPass123", appState: nil)
        }
        #expect(await signout.count() == 1)
    }

    @Test("AppState未提供でも認証成功と保存済み選択の更新を行う")
    func nilStateStillUpdatesDefaults() async throws {
        let defaults = DefaultUserDefaultsSpy()
        let fetcher = SignInSceneDataFetcherSpy(festivalPack: festivalPack(), districtPack: districtPack())
        var auth = AuthProviderSpy().client
        auth.confirmSignIn = { _ in }
        auth.getUserRole = { .headquarter("festival") }
        let useCase = withDependencies {
            $0.installTestSpies()
            $0.authProvider = auth
            $0[SceneDataFetcherKey.self] = fetcher
            $0[UserDefaltsManagerKey.self] = defaults
        } operation: { ConfirmSignInUseCase() }

        #expect(try await useCase(password: "ValidPass123", appState: nil) == .headquarter("festival"))
        #expect(defaults.defaultFestivalId == "festival")
        #expect(await fetcher.requestedResources() == ["festival"])
    }
}

private enum ConfirmSignInFailure: Swift.Error, Equatable {
    case denied
}
