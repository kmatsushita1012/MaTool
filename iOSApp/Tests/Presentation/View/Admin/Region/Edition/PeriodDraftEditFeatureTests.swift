import ComposableArchitecture
import Shared
import Testing
@testable import iOSApp

struct PeriodDraftEditFeatureTests {
    @Test("期間追加の日付編集はEdition所属と入力値を保持する")
    @MainActor
    func changingDateKeepsEditionAndFields() async {
        let period = Period(
            id: "new-period",
            editionId: "edition",
            festivalId: "festival",
            title: "夜",
            date: SimpleDate(year: 2026, month: 10, day: 1),
            start: SimpleTime(hour: 19, minute: 0),
            end: SimpleTime(hour: 22, minute: 0)
        )
        let store = TestStore(initialState: PeriodDraftEditFeature.State.create(period, festivalID: "festival")) {
            PeriodDraftEditFeature()
        }
        let newDate = SimpleDate(year: 2027, month: 10, day: 2)
        let updatedPeriod = Period(
            id: period.id,
            editionId: "edition",
            festivalId: "festival",
            title: period.title,
            date: newDate,
            start: period.start,
            end: period.end
        )

        await store.send(.dateChanged(newDate)) {
            $0.period = updatedPeriod
        }
        #expect(store.state.period.id == period.id)
        #expect(store.state.period.editionId == period.editionId)
        #expect(store.state.period.date == newDate)
        #expect(store.state.period.title == period.title)
        #expect(store.state.period.start == period.start)
        #expect(store.state.period.end == period.end)
        await store.finish()
    }

    @Test("既存期間の日付は編集できない")
    @MainActor
    func existingDateDoesNotChange() async {
        let period = Period(
            id: "period",
            editionId: "edition",
            festivalId: "festival",
            title: "昼",
            date: SimpleDate(year: 2026, month: 10, day: 1)
        )
        let store = TestStore(initialState: PeriodDraftEditFeature.State.update(period, festivalID: "festival")) {
            PeriodDraftEditFeature()
        }

        await store.send(.dateChanged(SimpleDate(year: 2027, month: 10, day: 1)))
        #expect(store.state.period == period)
        await store.finish()
    }
}
