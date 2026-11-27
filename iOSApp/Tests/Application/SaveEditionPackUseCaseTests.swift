import ComposableArchitecture
import Foundation
import Shared
import Testing
@testable import iOSApp

struct SaveEditionPackUseCaseTests {
    @Test("有効EditionのPack保存後はAppStateの期間とRouteを更新する")
    func savesActiveEditionToAppState() async throws {
        let edition = AppStateFixture.edition()
        let original = AppStateFixture.period(edition: edition)
        let updated = Period(
            id: original.id,
            editionId: edition.id,
            title: "更新済み",
            date: original.date,
            start: original.start,
            end: original.end
        )
        let keepRoute = AppStateFixture.route(id: "keep", periodId: original.id)
        let removeRoute = AppStateFixture.route(id: "remove", periodId: "removed-period")
        let appState = Shared<AppState?>(value: AppStateFixture.state(
            periods: [original],
            routes: [keepRoute, removeRoute],
            currentRouteId: removeRoute.id
        ))
        let pack = EditionPack(edition: edition, periods: [updated])
        let fetcher = makeSpy(edition: edition, pack: pack)

        let response = try await withDependencies {
            $0[EditionDataFetcherKey.self] = fetcher
        } operation: {
            try await SaveEditionPackUseCase()(pack, appState: appState)
        }

        #expect(response == pack)
        #expect(appState.wrappedValue?.festivalState.periods == [updated])
        #expect(appState.wrappedValue?.districtState?.routes == [keepRoute])
        #expect(appState.wrappedValue?.routeState == nil)
        #expect(await fetcher.calls() == [.update(edition.year, [updated.id])])
    }

    @Test("過去EditionのPack保存では有効EditionのAppStateを変更しない")
    func archiveSaveDoesNotReplaceActiveEdition() async throws {
        let activeEdition = AppStateFixture.edition()
        let activePeriod = AppStateFixture.period(edition: activeEdition)
        let appState = Shared<AppState?>(value: AppStateFixture.state(
            periods: [activePeriod],
            edition: activeEdition
        ))
        let archiveEdition = Edition(id: "archive", festivalId: activeEdition.festivalId, year: 2025)
        let archivePeriod = AppStateFixture.period(id: "archive-period", edition: archiveEdition)
        let pack = EditionPack(edition: archiveEdition, periods: [archivePeriod])
        let fetcher = makeSpy(edition: archiveEdition, pack: pack)

        _ = try await withDependencies {
            $0[EditionDataFetcherKey.self] = fetcher
        } operation: {
            try await SaveEditionPackUseCase()(pack, appState: appState)
        }

        #expect(appState.wrappedValue?.festivalState.edition == activeEdition)
        #expect(appState.wrappedValue?.festivalState.periods == [activePeriod])
    }

    private func makeSpy(edition: Edition, pack: EditionPack) -> EditionDataFetcherSpy {
        EditionDataFetcherSpy(
            list: EditionListResponse(editions: [edition], activeEditionId: edition.id),
            pack: pack,
            activeEdition: ActiveEdition(festivalId: edition.festivalId, editionId: edition.id),
            updatedPack: pack
        )
    }
}
