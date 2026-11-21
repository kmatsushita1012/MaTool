import ComposableArchitecture
import Dependencies
import Foundation
import Shared
import Testing
@testable import iOSApp

struct UpdatePeriodUseCaseTests {
    @Test("期間更新はEditionPackを保存し、サーバー応答をAppStateへ反映する")
    func updatesPeriodThroughEditionPack() async throws {
        let edition = AppStateFixture.edition()
        let original = AppStateFixture.period()
        let pack = EditionPack(edition: edition, periods: [original])
        var returned = original
        returned.title = "server version"
        let savedPack = EditionPack(edition: edition, periods: [returned])
        let spy = makeSpy(pack: pack, updatedPack: savedPack)
        let state = Shared<AppState?>(value: AppStateFixture.state())
        let useCase = withDependencies {
            $0.installTestSpies()
            $0[EditionDataFetcherKey.self] = spy
        } operation: { UpdatePeriodUseCase() }

        let actual = try await useCase(returned, appState: state)

        #expect(actual == returned)
        #expect(state.wrappedValue?.festivalState.periods == [returned])
        #expect(await spy.calls() == [
            .fetchList("festival"), .fetch("festival", 2026), .update(2026, ["period"])
        ])
    }

    @Test("過去Editionの日程を編集しても現在のFestivalStateは置き換えない")
    func archiveEditionDoesNotReplaceActivePeriods() async throws {
        let activeEdition = AppStateFixture.edition()
        let activePeriod = AppStateFixture.period()
        let archiveEdition = Edition(id: "archive", festivalId: "festival", year: 2025)
        let archivePeriod = AppStateFixture.period(id: "archive-period", edition: archiveEdition)
        var updatedArchivePeriod = archivePeriod
        updatedArchivePeriod.title = "archive updated"
        let pack = EditionPack(edition: archiveEdition, periods: [archivePeriod])
        let spy = makeSpy(
            pack: pack,
            updatedPack: EditionPack(edition: archiveEdition, periods: [updatedArchivePeriod])
        )
        let state = Shared<AppState?>(value: AppStateFixture.state(
            periods: [activePeriod], edition: activeEdition
        ))
        let useCase = withDependencies {
            $0.installTestSpies()
            $0[EditionDataFetcherKey.self] = spy
        } operation: { UpdatePeriodUseCase() }

        #expect(try await useCase(updatedArchivePeriod, appState: state) == updatedArchivePeriod)
        #expect(state.wrappedValue?.festivalState.periods == [activePeriod])
        #expect(await spy.calls().last == .update(2025, ["archive-period"]))
    }

    @Test("EditionPackに対象Periodがない場合は保存しない")
    func missingPeriodDoesNotSavePack() async {
        let edition = AppStateFixture.edition()
        let pack = EditionPack(edition: edition, periods: [])
        let spy = makeSpy(pack: pack)
        let original = AppStateFixture.state()
        let state = Shared<AppState?>(value: original)
        let useCase = withDependencies {
            $0.installTestSpies()
            $0[EditionDataFetcherKey.self] = spy
        } operation: { UpdatePeriodUseCase() }

        await #expect(throws: AppError.self) {
            try await useCase(AppStateFixture.period(), appState: state)
        }
        #expect(state.wrappedValue == original)
        #expect(await spy.calls() == [.fetchList("festival"), .fetch("festival", 2026)])
    }

    @Test("EditionPack保存失敗時はAppStateを変更しない")
    func saveFailurePreservesState() async {
        let edition = AppStateFixture.edition()
        let pack = EditionPack(edition: edition, periods: [AppStateFixture.period()])
        let original = AppStateFixture.state()
        let state = Shared<AppState?>(value: original)
        let spy = makeSpy(pack: pack, failures: [.update: .be(.network("offline"))])
        var changedPeriod = AppStateFixture.period()
        changedPeriod.title = "saved"
        let useCase = withDependencies {
            $0.installTestSpies()
            $0[EditionDataFetcherKey.self] = spy
        } operation: { UpdatePeriodUseCase() }

        await #expect(throws: AppError.self) {
            try await useCase(changedPeriod, appState: state)
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
