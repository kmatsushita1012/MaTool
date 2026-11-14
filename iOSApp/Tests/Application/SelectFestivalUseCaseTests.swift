import ComposableArchitecture
import Foundation
import Dependencies
import Shared
import Testing
@testable import iOSApp

struct SelectFestivalUseCaseTests {
    @Test("取得失敗時はAppStateと既定選択を保ち、同じ祭典を再試行できる")
    func failedFestivalFetchPreservesStateAndAllowsRetry() async throws {
        let currentFestival = Festival(
            id: "current", name: "Current", subname: "Current",
            base: Coordinate(latitude: 35, longitude: 139)
        )
        let nextFestival = Festival(
            id: "next", name: "Next", subname: "Next",
            base: Coordinate(latitude: 36, longitude: 140)
        )
        let currentPack = LaunchFestivalPack(
            festival: currentFestival, districts: [], periods: [], locations: [],
            checkpoints: [], hazardSections: []
        )
        let nextPack = LaunchFestivalPack(
            festival: nextFestival, districts: [], periods: [], locations: [],
            checkpoints: [], hazardSections: []
        )
        let appState = Shared<AppState?>(value: AppState(festivalPack: currentPack))
        let originalAppState = appState.wrappedValue
        let dataFetcher = SelectFestivalDataFetcherSpy(responses: [
            .failure(SelectFestivalTestError.fetch), .success(nextPack)
        ])
        let userDefaults = DefaultUserDefaultsSpy()
        let signOutSpy = SignInSignOutSpy()
        var auth = AuthProviderSpy().client
        auth.signOut = { await signOutSpy.record() }
        let useCase = withDependencies {
            $0.installTestSpies()
            $0.authProvider = auth
            $0[SceneDataFetcherKey.self] = dataFetcher
            $0[UserDefaltsManagerKey.self] = userDefaults
        } operation: {
            SelectFestivalUseCase()
        }

        do {
            _ = try await useCase(festivalId: nextFestival.id, appState: appState)
            Issue.record("取得失敗が伝播されませんでした")
        } catch SelectFestivalTestError.fetch {
            #expect(appState.wrappedValue == originalAppState)
            #expect(userDefaults.defaultFestivalId == nil)
            #expect(await signOutSpy.count() == 0)
        }

        let result = try await useCase(festivalId: nextFestival.id, appState: appState)
        #expect(result == .changed(.guest))
        #expect(await dataFetcher.festivalRequests == [nextFestival.id, nextFestival.id])
        #expect(appState.wrappedValue?.festivalState.festival.id == nextFestival.id)
        #expect(userDefaults.defaultFestivalId == nextFestival.id)
        #expect(await signOutSpy.count() == 1)
    }
    @Test("現在選択中の同一祭典では再取得とサインアウトを実行しない")
    func sameFestivalReturnsUnchangedWithoutNetwork() async throws {
        let defaults = DefaultUserDefaultsSpy(festivalId: "festival", districtId: "district")
        let signout = SignInSignOutSpy()
        var auth = AuthProviderSpy().client
        auth.signOut = { await signout.record() }
        let useCase = withDependencies {
            $0.installTestSpies()
            $0.authProvider = auth
            $0[UserDefaltsManagerKey.self] = defaults
        } operation: { SelectFestivalUseCase() }
        let state = Shared<AppState?>(value: AppStateFixture.state())
        let original = state.wrappedValue

        let result = try await useCase(festivalId: "festival", appState: state)

        #expect(result == .unchanged)
        #expect(state.wrappedValue == original)
        #expect(defaults.defaultDistrictId == "district")
        #expect(await signout.count() == 0)
    }

    @Test("ユーザーをログアウトさせない指定では取得と状態置換のみ実行する")
    func selectionWithoutSignoutPreservesAuthentication() async throws {
        let festival = AppStateFixture.festival()
        let pack = LaunchFestivalPack(
            festival: festival, districts: [], periods: [], locations: [],
            checkpoints: [], hazardSections: []
        )
        let fetcher = SelectFestivalDataFetcherSpy(responses: [.success(pack)])
        let defaults = DefaultUserDefaultsSpy(festivalId: "previous", districtId: "district")
        let state = Shared<AppState?>(value: nil)
        let useCase = withDependencies {
            $0.installTestSpies()
            $0[SceneDataFetcherKey.self] = fetcher
            $0[UserDefaltsManagerKey.self] = defaults
        } operation: { SelectFestivalUseCase() }

        let result = try await useCase(
            festivalId: "festival", appState: state, signOutCurrentUser: false
        )

        #expect(result == .changed(.guest))
        #expect(defaults.defaultFestivalId == "festival")
        #expect(defaults.defaultDistrictId == nil)
        #expect(state.wrappedValue?.festivalState.festival.id == "festival")
    }

    @Test("サインアウト失敗時は旧セッションと既定祭典を保持する")
    func signoutFailurePreservesStateAndDefaults() async {
        let pack = LaunchFestivalPack(
            festival: AppStateFixture.festival(),
            districts: [], periods: [], locations: [],
            checkpoints: [], hazardSections: []
        )
        let fetcher = SelectFestivalDataFetcherSpy(responses: [.success(pack)])
        let defaults = DefaultUserDefaultsSpy(festivalId: "previous", districtId: "district")
        let state = Shared<AppState?>(value: AppStateFixture.state())
        let previous = state.wrappedValue
        var auth = AuthProviderSpy().client
        auth.signOut = { throw SelectFestivalTestError.fetch }
        let useCase = withDependencies {
            $0.installTestSpies()
            $0[SceneDataFetcherKey.self] = fetcher
            $0[UserDefaltsManagerKey.self] = defaults
            $0.authProvider = auth
        } operation: { SelectFestivalUseCase() }

        await #expect(throws: SelectFestivalTestError.fetch) {
            try await useCase(festivalId: "festival", appState: state)
        }
        #expect(state.wrappedValue == previous)
        #expect(defaults.defaultFestivalId == "previous")
        #expect(defaults.defaultDistrictId == "district")
    }

    @Test("取得中に新しいセッションが開始されると古い結果を採用しない")
    func supersededFetchAvoidsMutationOrSignout() async {
        let coordinator = SceneSessionCoordinatorSpy()
        let pack = LaunchFestivalPack(
            festival: AppStateFixture.festival(), districts: [],
            periods: [], locations: [], checkpoints: [], hazardSections: []
        )
        let fetcher = SupersedingFestivalFetcherSpy(
            response: pack, sessionCoordinator: coordinator
        )
        let signout = SignInSignOutSpy()
        var auth = AuthProviderSpy().client
        auth.signOut = { await signout.record() }
        let defaults = DefaultUserDefaultsSpy(festivalId: "previous")
        let state = Shared<AppState?>(value: AppStateFixture.state())
        let original = state.wrappedValue
        let useCase = withDependencies {
            $0.installTestSpies()
            $0.authProvider = auth
            $0[UserDefaltsManagerKey.self] = defaults
            $0[SceneDataFetcherKey.self] = fetcher
            $0[SceneSessionCoordinatorKey.self] = coordinator
        } operation: { SelectFestivalUseCase() }

        await #expect(throws: CancellationError.self) {
            try await useCase(festivalId: "festival", appState: state)
        }
        #expect(state.wrappedValue == original)
        #expect(defaults.defaultFestivalId == "previous")
        #expect(await signout.count() == 0)
    }

    @Test("サインアウト直後にセッションが更新された場合は古い管理者状態を破棄する")
    func supersededAfterSignoutClearsStaleAdminState() async {
        let coordinator = SceneSessionCoordinatorSpy()
        let pack = LaunchFestivalPack(
            festival: AppStateFixture.festival(), districts: [],
            periods: [], locations: [], checkpoints: [], hazardSections: []
        )
        let fetcher = SelectFestivalDataFetcherSpy(responses: [.success(pack)])
        let defaults = DefaultUserDefaultsSpy(festivalId: "previous")
        let state = Shared<AppState?>(value: AppStateFixture.state())
        var auth = AuthProviderSpy().client
        auth.signOut = { _ = await coordinator.beginSession() }
        let useCase = withDependencies {
            $0.installTestSpies()
            $0.authProvider = auth
            $0[SceneDataFetcherKey.self] = fetcher
            $0[SceneSessionCoordinatorKey.self] = coordinator
            $0[UserDefaltsManagerKey.self] = defaults
        } operation: { SelectFestivalUseCase() }

        await #expect(throws: CancellationError.self) {
            try await useCase(festivalId: "festival", appState: state)
        }
        #expect(state.wrappedValue == nil)
        #expect(defaults.defaultFestivalId == "previous")
    }

}

private enum SelectFestivalTestError: Error {
    case fetch
}

private struct SupersedingFestivalFetcherSpy: SceneDataFetcherProtocol {
    let response: LaunchFestivalPack
    let sessionCoordinator: SceneSessionCoordinatorSpy

    func launchFestival(festivalId: Festival.ID) async throws -> LaunchFestivalPack {
        _ = await sessionCoordinator.beginSession()
        return response
    }

    func launchFestival(districtId: District.ID) async throws -> LaunchFestivalPack {
        throw CancellationError()
    }

    func launchDistrict(districtId: District.ID, periodId: Period.ID?) async throws -> LaunchDistrictPack {
        throw CancellationError()
    }
}
