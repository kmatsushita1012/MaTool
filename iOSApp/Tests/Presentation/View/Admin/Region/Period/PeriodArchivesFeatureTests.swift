import ComposableArchitecture
import Shared
import Testing
@testable import iOSApp

struct PeriodArchivesFeatureTests {
    @Test("過去年度の期間を日時順で表示し、元の配列は改変しない")
    func sortsArchivedPeriodsOnInitialization() {
        let earlier = AppStateFixture.period(id: "earlier", day: 1)
        let later = AppStateFixture.period(id: "later", day: 4)
        let state = PeriodArchivesFeature.State(
            festivalId: "festival", year: 2026,
            periods: [later, earlier],
            appState: Shared(value: Optional(AppStateFixture.state()))
        )

        #expect(state.periods.map(\.id) == ["earlier", "later"])
        #expect(state.year == 2026)
        #expect(state.festivalId == "festival")
    }

    @Test("過去期間選択は対応する編集画面を開く")
    @MainActor
    func selectedPeriodOpensEditor() async {
        let period = AppStateFixture.period()
        let state = PeriodArchivesFeature.State(
            festivalId: "festival", year: 2026, periods: [period],
            appState: Shared(value: Optional(AppStateFixture.state()))
        )
        let store = TestStore(initialState: state) {
            PeriodArchivesFeature()
        } withDependencies: { $0.installTestSpies() }
        store.exhaustivity = .off

        await store.send(.periodTapped(period))

        #expect(store.state.destination?.edit != nil)
        await store.finish()
    }
}
