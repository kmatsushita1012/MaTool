import ComposableArchitecture
import Shared
import Testing
@testable import iOSApp

struct PeriodListFeatureTests {
    @Test("年度ごとに期間を分類し、新しい年度を先に提示する")
    func groupsByYear() {
        let current = AppStateFixture.period(id: "current")
        let previous = Period(
            id: "old", festivalId: "festival",
            date: SimpleDate(year: 2025, month: 10, day: 2),
            start: SimpleTime(hour: 9, minute: 0),
            end: SimpleTime(hour: 17, minute: 0)
        )
        let state = PeriodListFeature.State(
            festivalId: "festival", periods: [previous, current],
            appState: Shared(value: Optional(AppStateFixture.state()))
        )

        #expect(state.latests?.year == 2026)
        #expect(state.latests?.periods.map(\.id) == ["current"])
        #expect(state.archives.map(\.year) == [2025])
        #expect(state.yearOptions == [2025, 2026])
        #expect(state.createYear == 2027)
    }

    @Test("同じIDの期間は置換され、開始時刻順に並べ直す")
    func upsertsPeriodById() {
        let original = AppStateFixture.period()
        let earlier = AppStateFixture.period(id: "earlier", day: 1)
        var state = PeriodListFeature.State(
            festivalId: "festival", periods: [original],
            appState: Shared(value: Optional(AppStateFixture.state()))
        )

        state.upsert(earlier)
        #expect(state.periods.map(\.id) == ["earlier", "period"])

        var changed = original
        changed.title = "changed"
        state.upsert(changed)
        #expect(state.periods.count == 2)
        #expect(state.periods.last?.title == "changed")
    }

    @Test("期間一括作成の成功結果を反映して処理を終了する")
    @MainActor
    func batchSuccessUpdatesListAndStopsLoading() async {
        let state = PeriodListFeature.State(
            festivalId: "festival", periods: [],
            appState: Shared(value: Optional(AppStateFixture.state()))
        )
        let store = TestStore(initialState: state) {
            PeriodListFeature()
        } withDependencies: { $0.installTestSpies() }
        let created = AppStateFixture.period(id: "created")

        await store.send(.batchCreateReceived(.success([created]))) {
            $0.periods = [created]
            $0.alert = AlertFeature.notice("一括作成が完了しました。")
        }
        await store.finish()
    }

    @Test("期間一括作成失敗時は取得済み期間を維持してエラー表示する")
    @MainActor
    func batchFailurePreservesList() async {
        var state = PeriodListFeature.State(
            festivalId: "festival", periods: [AppStateFixture.period()],
            appState: Shared(value: Optional(AppStateFixture.state()))
        )
        state.isLoading = true
        let store = TestStore(initialState: state) {
            PeriodListFeature()
        } withDependencies: { $0.installTestSpies() }
        let error = AppError.be(.network("offline"))

        await store.send(.batchCreateReceived(.failure(error))) {
            $0.isLoading = false
            $0.alert = AlertFeature.error(error.message)
        }
        #expect(store.state.periods.map(\.id) == ["period"])
        await store.finish()
    }

    @Test("過去年度一覧と新規登録の遷移先を作成する")
    @MainActor
    func opensArchivesAndCreateScreen() async {
        let period = AppStateFixture.period()
        let state = PeriodListFeature.State(
            festivalId: "festival", periods: [period],
            appState: Shared(value: Optional(AppStateFixture.state()))
        )
        let store = TestStore(initialState: state) {
            PeriodListFeature()
        } withDependencies: { $0.installTestSpies() }
        store.exhaustivity = .off

        await store.send(.archiveTapped(.init(year: 2026, periods: [period])))
        #expect(store.state.destination?.archives != nil)
        await store.send(.periodCreateTapped)
        #expect(store.state.destination?.edit != nil)
        await store.finish()
    }
    @Test("空の期間一覧では今年を新規作成の起点とし年度一覧は空になる")
    func emptyListUsesCurrentYear() {
        let state = PeriodListFeature.State(
            festivalId: "festival", periods: [],
            appState: Shared<AppState?>(value: AppStateFixture.state())
        )
        #expect(state.latests == nil)
        #expect(state.archives.isEmpty)
        #expect(state.yearOptions.isEmpty)
        #expect(state.createYear == SimpleDate.now.year)
    }

    @Test("期間をタップすると編集画面には同じ期間IDが渡される")
    @MainActor
    func periodTappedOpensUpdateEditor() async {
        let period = AppStateFixture.period()
        let store = TestStore(initialState: makeState([period])) {
            PeriodListFeature()
        } withDependencies: { $0.installTestSpies() }
        store.exhaustivity = .off
        await store.send(.periodTapped(period))
        #expect(store.state.destination?.edit != nil)
        await store.finish()
    }

    @Test("対象年度に期間が無い一括作成はUseCaseを呼ばず成功を返す")
    @MainActor
    func emptyBatchDoesNotCallCreateUseCase() async {
        let spy = PeriodCreateUseCaseSpy(returning: AppStateFixture.period(id: "unused"))
        let store = TestStore(initialState: makeState([AppStateFixture.period()])) {
            PeriodListFeature()
        } withDependencies: {
            $0.installTestSpies()
            $0[CreatePeriodUseCaseKey.self] = spy
        }

        await store.send(.batchCreateTapped(1999)) {
            $0.isLoading = true
        }
        await store.receive(.batchCreateReceived(.success([]))) {
            $0.isLoading = false
            $0.alert = AlertFeature.notice("一括作成が完了しました。")
        }
        #expect(await spy.created.isEmpty)
        await store.finish()
    }

    @Test("指定年度を一括作成すると元のタイトルと開始終了時刻を引き継ぐ")
    @MainActor
    func batchCreationInvokesUseCaseWithCopiedPeriod() async {
        var original = AppStateFixture.period()
        original.title = "night"
        let created = AppStateFixture.period(id: "server-created", day: 4)
        let spy = PeriodCreateUseCaseSpy(returning: created)
        let store = TestStore(initialState: makeState([original])) {
            PeriodListFeature()
        } withDependencies: {
            $0.installTestSpies()
            $0[CreatePeriodUseCaseKey.self] = spy
        }

        await store.send(.batchCreateTapped(2026)) {
            $0.isLoading = true
        }
        await store.receive(.batchCreateReceived(.success([created]))) {
            $0.isLoading = false
            $0.periods = [original, created].sorted()
            $0.alert = AlertFeature.notice("一括作成が完了しました。")
        }

        let sent = try #require(await spy.created.first)
        #expect(sent.festivalId == original.festivalId)
        #expect(sent.title == original.title)
        #expect(sent.start == original.start)
        #expect(sent.end == original.end)
        #expect(sent.date.year == 2027)
        #expect(store.state.periods.contains(where: { $0.id == created.id }))
        await store.finish()
    }

    @Test("一括作成後の通知アラートを閉じても期間データを消さない")
    @MainActor
    func alertDismissKeepsPeriods() async {
        var state = makeState([AppStateFixture.period()])
        state.alert = AlertFeature.notice("一括作成が完了しました。")
        let store = TestStore(initialState: state) {
            PeriodListFeature()
        } withDependencies: { $0.installTestSpies() }

        await store.send(.alert(.presented(.okTapped))) {
            $0.alert = nil
        }
        #expect(store.state.periods.count == 1)
        await store.finish()
    }

    private func makeState(_ periods: [Period]) -> PeriodListFeature.State {
        PeriodListFeature.State(
            festivalId: "festival", periods: periods,
            appState: Shared<AppState?>(value: AppStateFixture.state())
        )
    }

}

private actor PeriodCreateUseCaseSpy: CreatePeriodUseCaseProtocol {
    private(set) var created: [Period] = []
    let result: Period

    init(returning result: Period) { self.result = result }

    func callAsFunction(_ period: Period, appState: Shared<AppState?>) async throws -> Period {
        created.append(period)
        return result
    }
}
