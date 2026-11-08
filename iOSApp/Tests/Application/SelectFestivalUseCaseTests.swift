import ComposableArchitecture
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
}

private enum SelectFestivalTestError: Error {
    case fetch
}
