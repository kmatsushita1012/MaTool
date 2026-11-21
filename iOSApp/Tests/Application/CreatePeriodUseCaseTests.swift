import ComposableArchitecture
import Dependencies
import Shared
import Testing
@testable import iOSApp

struct CreatePeriodUseCaseTests {
    @Test("期間の作成はEditionPackを保存し、保存後の期間をAppStateへ反映する")
    func createsPeriodThroughEditionPack() async throws {
        let edition = AppStateFixture.edition()
        let existing = AppStateFixture.period()
        let submitted = AppStateFixture.period(id: "temporary", day: 4)
        var returned = submitted
        returned.title = "normalized"
        let originalPack = EditionPack(edition: edition, periods: [existing])
        let savedPack = EditionPack(edition: edition, periods: [existing, returned])
        let spy = makeSpy(pack: originalPack, updatedPack: savedPack)
        let state = Shared<AppState?>(value: AppStateFixture.state())
        let useCase = withDependencies {
            $0.installTestSpies()
            $0[EditionDataFetcherKey.self] = spy
        } operation: { CreatePeriodUseCase() }

        let actual = try await useCase(submitted, appState: state)

        #expect(actual == returned)
        #expect(state.wrappedValue?.festivalState.periods == [existing, returned].sorted())
        #expect(await spy.calls() == [
            .fetchList("festival"), .fetch("festival", 2026), .update(2026, ["period", "temporary"])
        ])
    }

    @Test("EditionPack保存失敗時はAppStateを変更しない")
    func failureDoesNotMutateState() async {
        let edition = AppStateFixture.edition()
        let pack = EditionPack(edition: edition, periods: [AppStateFixture.period()])
        let failure = AppError.be(.network("offline"))
        let spy = makeSpy(pack: pack, failures: [.update: failure])
        let original = AppStateFixture.state()
        let state = Shared<AppState?>(value: original)
        let useCase = withDependencies {
            $0.installTestSpies()
            $0[EditionDataFetcherKey.self] = spy
        } operation: { CreatePeriodUseCase() }

        await #expect(throws: failure) {
            try await useCase(AppStateFixture.period(id: "new"), appState: state)
        }
        #expect(state.wrappedValue == original)
    }

    @Test("AppStateまたはEditionがない場合は個別Period APIへ書き込まない")
    func missingEditionCannotCreatePeriod() async {
        let state = Shared<AppState?>(value: nil)
        let useCase = withDependencies {
            $0.installTestSpies()
        } operation: { CreatePeriodUseCase() }

        await #expect(throws: AppError.self) {
            try await useCase(AppStateFixture.period(), appState: state)
        }
        #expect(state.wrappedValue == nil)
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
