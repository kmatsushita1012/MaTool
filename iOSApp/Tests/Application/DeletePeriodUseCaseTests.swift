import ComposableArchitecture
import Dependencies
import Shared
import Testing
@testable import iOSApp

struct DeletePeriodUseCaseTests {
    @Test("削除はEditionPackを保存した後にAppStateから関連PeriodとRouteを除く")
    func deletesPeriodThroughEditionPack() async throws {
        let edition = AppStateFixture.edition()
        let period = AppStateFixture.period()
        let route = AppStateFixture.route()
        let pack = EditionPack(edition: edition, periods: [period])
        let spy = makeSpy(pack: pack, updatedPack: EditionPack(edition: edition, periods: []))
        let state = Shared<AppState?>(value: AppStateFixture.state(
            routes: [route], currentRouteId: route.id
        ))
        let useCase = withDependencies {
            $0.installTestSpies()
            $0[EditionDataFetcherKey.self] = spy
        } operation: { DeletePeriodUseCase() }

        try await useCase(period, appState: state)

        #expect(await spy.calls() == [
            .fetchList("festival"), .fetch("festival", 2026), .update(2026, [])
        ])
        #expect(state.wrappedValue?.festivalState.periods.isEmpty == true)
        #expect(state.wrappedValue?.districtState?.routes.isEmpty == true)
        #expect(state.wrappedValue?.routeState == nil)
    }

    @Test("対象PeriodがEditionPackにない場合は保存しない")
    func missingPeriodDoesNotSavePack() async {
        let edition = AppStateFixture.edition()
        let spy = makeSpy(pack: EditionPack(edition: edition, periods: []))
        let original = AppStateFixture.state()
        let state = Shared<AppState?>(value: original)
        let useCase = withDependencies {
            $0.installTestSpies()
            $0[EditionDataFetcherKey.self] = spy
        } operation: { DeletePeriodUseCase() }

        await #expect(throws: AppError.self) {
            try await useCase(AppStateFixture.period(), appState: state)
        }
        #expect(state.wrappedValue == original)
        #expect(await spy.calls() == [.fetchList("festival"), .fetch("festival", 2026)])
    }

    @Test("EditionPack保存失敗時はAppStateを変更しない")
    func errorPreservesState() async {
        let edition = AppStateFixture.edition()
        let period = AppStateFixture.period()
        let original = AppStateFixture.state()
        let state = Shared<AppState?>(value: original)
        let spy = makeSpy(
            pack: EditionPack(edition: edition, periods: [period]),
            failures: [.update: .be(.network("offline"))]
        )
        let useCase = withDependencies {
            $0.installTestSpies()
            $0[EditionDataFetcherKey.self] = spy
        } operation: { DeletePeriodUseCase() }

        await #expect(throws: AppError.self) {
            try await useCase(period, appState: state)
        }
        #expect(state.wrappedValue == original)
    }

    private func makeSpy(
        pack: EditionPack,
        updatedPack: EditionPack? = nil,
        failures: [EditionDataFetcherSpy.Operation: AppError] = [:]
    ) -> EditionDataFetcherSpy {
        EditionDataFetcherSpy(
            list: EditionListResponse(editions: [pack.edition], activeEditionId: pack.edition.id),
            pack: pack,
            activeEdition: ActiveEdition(festivalId: pack.edition.festivalId, editionId: pack.edition.id),
            failures: failures,
            updatedPack: updatedPack
        )
    }
}
