import ComposableArchitecture
import Shared
import Testing
@testable import iOSApp

struct EditionEditFeatureTests {
    @Test("日程の追加・編集・削除はPack保存までネットワークへ送らない")
    @MainActor
    func periodDraftsStayLocalUntilPackSave() async {
        let edition = edition()
        let original = period(id: "period", edition: edition)
        let edited = Period(
            id: original.id,
            editionId: edition.id,
            festivalId: edition.festivalId,
            title: "夜",
            date: original.date,
            start: original.start,
            end: original.end
        )
        let response = EditionPack(edition: edition, periods: [edited])
        let spy = makeSpy(edition: edition, pack: response)
        let store = TestStore(initialState: EditionEditFeature.State(
            festivalID: edition.festivalId,
            pack: EditionPack(edition: edition, periods: [original]),
            activeEditionID: nil
        )) {
            EditionEditFeature()
        } withDependencies: {
            $0[EditionDataFetcherKey.self] = spy
        }
        store.exhaustivity = .off

        await store.send(.periodTapped(original))
        await store.send(.periodEditor(.presented(.binding(.set(\.period.title, "夜")))))
        await store.send(.periodEditor(.presented(.saveTapped)))
        #expect(store.state.periods == [edited])
        #expect(store.state.isDirty)
        #expect(await spy.calls().isEmpty)

        await store.send(.saveTapped)
        await store.receive(.saveReceived(.success(response)))
        #expect(await spy.calls() == [.update(2026, ["period"])])
        #expect(store.state.periods == [edited])
        #expect(!store.state.isDirty)
        await store.finish()
    }

    @Test("期間削除は下書きから除き、EditionPack保存時に一括反映する")
    @MainActor
    func deletionIsDeferredUntilSave() async {
        let edition = edition()
        let original = period(id: "period", edition: edition)
        let emptyPack = EditionPack(edition: edition, periods: [])
        let spy = makeSpy(edition: edition, pack: emptyPack)
        let store = TestStore(initialState: EditionEditFeature.State(
            festivalID: edition.festivalId,
            pack: EditionPack(edition: edition, periods: [original]),
            activeEditionID: nil
        )) {
            EditionEditFeature()
        } withDependencies: {
            $0[EditionDataFetcherKey.self] = spy
        }
        store.exhaustivity = .off

        await store.send(.periodTapped(original))
        await store.send(.periodEditor(.presented(.deleteTapped)))
        #expect(store.state.periods.isEmpty)
        #expect(store.state.isDirty)
        #expect(await spy.calls().isEmpty)

        await store.send(.saveTapped)
        await store.receive(.saveReceived(.success(emptyPack)))
        #expect(await spy.calls() == [.update(2026, [])])
        #expect(store.state.periods.isEmpty)
        await store.finish()
    }

    @Test("有効化は保存とは別のAPI操作で、Periodが0件でも実行できる")
    @MainActor
    func activationIsSeparateAndAllowsEmptyEdition() async {
        let edition = edition()
        let pack = EditionPack(edition: edition, periods: [])
        let active = ActiveEdition(festivalId: edition.festivalId, editionId: edition.id)
        let spy = makeSpy(edition: edition, pack: pack, activeEdition: active)
        let store = TestStore(initialState: EditionEditFeature.State(
            festivalID: edition.festivalId,
            pack: pack,
            activeEditionID: nil
        )) {
            EditionEditFeature()
        } withDependencies: {
            $0[EditionDataFetcherKey.self] = spy
        }
        store.exhaustivity = .off

        await store.send(.activateTapped)
        await store.receive(.activationReceived(.success(active)))
        #expect(store.state.isActive)
        #expect(await spy.calls() == [.activate("festival", "edition")])
        await store.finish()
    }

    @Test("Edition取得失敗はエラーを表示する")
    @MainActor
    func fetchFailureShowsError() async {
        let edition = edition()
        let pack = EditionPack(edition: edition, periods: [])
        let error = AppError.be(.forbidden("権限がありません"))
        let spy = makeSpy(edition: edition, pack: pack, failures: [.fetch: error])
        let store = TestStore(initialState: EditionEditFeature.State(
            festivalID: edition.festivalId,
            edition: edition,
            activeEditionID: nil
        )) {
            EditionEditFeature()
        } withDependencies: {
            $0[EditionDataFetcherKey.self] = spy
        }
        store.exhaustivity = .off

        await store.send(.onAppear)
        await store.receive(.packReceived(.failure(error)))
        #expect(!store.state.hasLoaded)
        #expect(store.state.hasLoadError)
        #expect(await spy.calls() == [.fetch("festival", 2026)])
        await store.finish()
    }

    @Test("保存失敗を表示しつつサーバーのPackを再取得し編集内容は保つ")
    @MainActor
    func saveFailureRefreshesServerSnapshot() async {
        let edition = edition()
        let period = period(id: "period", edition: edition)
        let pack = EditionPack(edition: edition, periods: [period])
        let error = AppError.be(.forbidden("権限がありません"))
        let spy = makeSpy(edition: edition, pack: pack)
        let store = TestStore(initialState: EditionEditFeature.State(
            festivalID: edition.festivalId,
            pack: pack,
            activeEditionID: nil
        )) {
            EditionEditFeature()
        } withDependencies: {
            $0[EditionDataFetcherKey.self] = spy
        }
        store.exhaustivity = .off

        await store.send(.saveReceived(.failure(error)))
        await store.receive(.serverSnapshotReceived(.success(pack)))
        #expect(store.state.alert == AlertFeature.error("保存に失敗しました。編集内容は保持しています。\n権限がありません"))
        #expect(store.state.periods == [period])
        #expect(await spy.calls() == [.fetch("festival", 2026)])
        await store.finish()
    }

    private func makeSpy(
        edition: Edition,
        pack: EditionPack,
        activeEdition: ActiveEdition? = nil,
        failures: [EditionDataFetcherSpy.Operation: AppError] = [:]
    ) -> EditionDataFetcherSpy {
        EditionDataFetcherSpy(
            list: EditionListResponse(editions: [edition], activeEditionId: nil),
            pack: pack,
            activeEdition: activeEdition ?? ActiveEdition(festivalId: edition.festivalId, editionId: edition.id),
            failures: failures
        )
    }

    private func edition() -> Edition {
        Edition(id: "edition", festivalId: "festival", year: 2026)
    }

    private func period(id: Period.ID, edition: Edition) -> Period {
        Period(
            id: id,
            editionId: edition.id,
            festivalId: edition.festivalId,
            title: "昼",
            date: SimpleDate(year: edition.year, month: 10, day: 1),
            start: SimpleTime(hour: 9, minute: 0),
            end: SimpleTime(hour: 12, minute: 0)
        )
    }
}
