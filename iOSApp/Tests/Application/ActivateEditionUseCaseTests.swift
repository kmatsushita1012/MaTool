import ComposableArchitecture
import Dependencies
import Shared
import Testing
@testable import iOSApp

struct ActivateEditionUseCaseTests {
    @Test("Edition有効化後にFestival・District・RouteのAppStateを再構築する")
    func activationReloadsCompleteAppState() async throws {
        let oldState = AppStateFixture.state(
            routes: [AppStateFixture.route()],
            currentRouteId: "route"
        )
        let oldSessionID = oldState.sessionId
        let appState = Shared<AppState?>(value: oldState)
        let edition = Edition(id: "next-edition", festivalId: "festival", year: 2027)
        let period = AppStateFixture.period(id: "next-period", edition: edition)
        let route = AppStateFixture.route(id: "next-route", periodId: period.id)
        let festivalPack = LaunchFestivalPack(
            festival: AppStateFixture.festival(),
            edition: edition,
            districts: [AppStateFixture.district()],
            periods: [period],
            locations: [],
            checkpoints: [],
            hazardSections: []
        )
        let districtPack = LaunchDistrictPack(
            editionId: edition.id,
            performances: [],
            routes: [route],
            points: [],
            passages: [],
            currentRouteId: route.id
        )
        let activeEdition = ActiveEdition(festivalId: "festival", editionId: edition.id)
        let editionFetcher = EditionDataFetcherSpy(
            list: EditionListResponse(editions: [edition], activeEditionId: edition.id),
            pack: EditionPack(edition: edition, periods: [period]),
            activeEdition: activeEdition
        )
        let sceneFetcher = LaunchPairSequenceDataFetcherSpy(
            festivalResponses: [festivalPack],
            districtResponses: [districtPack]
        )
        let useCase = withDependencies {
            $0.installTestSpies()
            $0[EditionDataFetcherKey.self] = editionFetcher
            $0[SceneDataFetcherKey.self] = sceneFetcher
        } operation: {
            ActivateEditionUseCase()
        }

        let result = try await useCase(
            festivalID: "festival",
            editionID: edition.id,
            appState: appState
        )

        #expect(result == EditionActivationResult(activeEdition: activeEdition, appStateReloadError: nil))
        let reloaded = try #require(appState.wrappedValue)
        #expect(reloaded.sessionId != oldSessionID)
        #expect(reloaded.festivalState.edition == edition)
        #expect(reloaded.festivalState.periods == [period])
        #expect(reloaded.districtState?.routes == [route])
        #expect(reloaded.routeState?.route == route)
        #expect(reloaded.selectedDistrict?.id == "district")
        #expect(await editionFetcher.calls() == [.activate("festival", edition.id)])
        #expect(await sceneFetcher.callCounts().festival == 1)
        #expect(await sceneFetcher.callCounts().district == 1)
    }

    @Test("起動データのEdition不一致時は有効化成功と再取得失敗を分けて返す")
    func mismatchReportsReloadErrorAfterSuccessfulActivation() async throws {
        let oldState = AppStateFixture.state(
            routes: [AppStateFixture.route()],
            currentRouteId: "route"
        )
        let appState = Shared<AppState?>(value: oldState)
        let activeEdition = ActiveEdition(festivalId: "festival", editionId: "next-edition")
        let edition = Edition(id: "next-edition", festivalId: "festival", year: 2027)
        let editionFetcher = EditionDataFetcherSpy(
            list: EditionListResponse(editions: [edition], activeEditionId: edition.id),
            pack: EditionPack(edition: edition, periods: []),
            activeEdition: activeEdition
        )
        let sceneFetcher = LaunchPairSequenceDataFetcherSpy(
            festivalResponses: [festivalPack(editionID: "festival-edition")],
            districtResponses: [districtPack(editionID: "district-edition")]
        )
        let useCase = withDependencies {
            $0.installTestSpies()
            $0[EditionDataFetcherKey.self] = editionFetcher
            $0[SceneDataFetcherKey.self] = sceneFetcher
        } operation: {
            ActivateEditionUseCase()
        }

        let result = try await useCase(
            festivalID: "festival",
            editionID: edition.id,
            appState: appState
        )

        #expect(result.activeEdition == activeEdition)
        #expect(result.appStateReloadError == .be(.conflict("祭典と地区の起動データで有効な年度が一致しません。再度お試しください。")))
        #expect(appState.wrappedValue == oldState)
        #expect(await sceneFetcher.callCounts().festival == 2)
        #expect(await sceneFetcher.callCounts().district == 2)
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
