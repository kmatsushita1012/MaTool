import ComposableArchitecture
import Dependencies
import Shared
import Testing
@testable import iOSApp

struct ReloadAppStateUseCaseTests {
    @Test("Edition切り替え後はFestival・District・Routeを再取得してAppState全体を再構築する")
    func reloadsCompleteAppStateForNewEdition() async throws {
        let oldState = AppStateFixture.state(routes: [AppStateFixture.route()], currentRouteId: "route")
        let oldSessionID = oldState.sessionId
        let state = Shared<AppState?>(value: oldState)
        let newEdition = Edition(id: "next-edition", festivalId: "festival", year: 2027)
        let newPeriod = AppStateFixture.period(id: "next-period", edition: newEdition)
        let newRoute = AppStateFixture.route(id: "next-route", periodId: newPeriod.id)
        let festivalPack = LaunchFestivalPack(
            festival: AppStateFixture.festival(),
            edition: newEdition,
            districts: [AppStateFixture.district()],
            periods: [newPeriod],
            locations: [],
            checkpoints: [],
            hazardSections: []
        )
        let districtPack = LaunchDistrictPack(
            editionId: newEdition.id,
            performances: [],
            routes: [newRoute],
            points: [],
            passages: [],
            currentRouteId: newRoute.id
        )
        let fetcher = LaunchPairSequenceDataFetcherSpy(
            festivalResponses: [festivalPack],
            districtResponses: [districtPack]
        )
        let useCase = withDependencies {
            $0.installTestSpies()
            $0[SceneDataFetcherKey.self] = fetcher
        } operation: { ReloadAppStateUseCase() }

        try await useCase(appState: state)

        let reloaded = try #require(state.wrappedValue)
        #expect(reloaded.sessionId != oldSessionID)
        #expect(reloaded.festivalState.edition == newEdition)
        #expect(reloaded.festivalState.periods == [newPeriod])
        #expect(reloaded.districtState?.routes == [newRoute])
        #expect(reloaded.routeState?.route == newRoute)
        #expect(reloaded.selectedDistrict?.id == "district")
        #expect(await fetcher.callCounts().festival == 1)
        #expect(await fetcher.callCounts().district == 1)
    }

    @Test("Edition不一致が解消しない場合は混在したAppStateを返さない")
    func persistentMismatchKeepsExistingCompleteState() async {
        let original = AppStateFixture.state(routes: [AppStateFixture.route()], currentRouteId: "route")
        let originalEditionID = original.festivalState.edition?.id
        let originalRouteID = original.routeState?.route.id
        let state = Shared<AppState?>(value: original)
        let fetcher = LaunchPairSequenceDataFetcherSpy(
            festivalResponses: [festivalPack(editionID: "festival-new")],
            districtResponses: [districtPack(editionID: "district-new")]
        )
        let useCase = withDependencies {
            $0.installTestSpies()
            $0[SceneDataFetcherKey.self] = fetcher
        } operation: { ReloadAppStateUseCase() }

        await #expect(throws: AppError.self) {
            try await useCase(appState: state)
        }

        #expect(state.wrappedValue?.festivalState.edition?.id == originalEditionID)
        #expect(state.wrappedValue?.districtState?.editionId == original.districtState?.editionId)
        #expect(state.wrappedValue?.routeState?.route.id == originalRouteID)
        #expect(await fetcher.callCounts().festival == 2)
        #expect(await fetcher.callCounts().district == 2)
    }

    private func festivalPack(editionID: Edition.ID) -> LaunchFestivalPack {
        LaunchFestivalPack(
            festival: AppStateFixture.festival(),
            edition: Edition(id: editionID, festivalId: "festival", year: 2027),
            districts: [AppStateFixture.district()],
            periods: [],
            locations: [],
            checkpoints: [],
            hazardSections: []
        )
    }

    private func districtPack(editionID: Edition.ID) -> LaunchDistrictPack {
        LaunchDistrictPack(
            editionId: editionID,
            performances: [],
            routes: [],
            points: [],
            passages: [],
            currentRouteId: nil
        )
    }
}
