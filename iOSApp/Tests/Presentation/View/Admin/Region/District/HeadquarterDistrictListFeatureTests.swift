import ComposableArchitecture
import Foundation
import Shared
import Testing
@testable import iOSApp

struct HeadquarterDistrictListFeatureTests {
    private func fixtures() -> (Festival, AppState, District, District) {
        var a = AppStateFixture.district(id: "a", name: "Alpha")
        a.order = 1
        var b = AppStateFixture.district(id: "b", name: "Bravo")
        b.order = 2
        let state = AppStateFixture.state(districts: [b, a], selectedDistrictId: nil)
        return (AppStateFixture.festival(), state, a, b)
    }

    @Test("検索文字列で地区を絞り込み、並べ替え中はドラフトの順序を使う")
    func filtersDistrictsAndUsesDraftOrder() {
        let (festival, appState, a, b) = fixtures()
        var state = HeadquarterDistrictListFeature.State(
            festival, appState: Shared(value: Optional(appState))
        )

        #expect(state.filteredDistricts.map(\.id) == ["a", "b"])
        state.searchText = "Bravo"
        #expect(state.filteredDistricts.map(\.id) == ["b"])
        #expect(state.isReorderDisabled)

        state.isReordering = true
        state.draftDistricts = [b, a]
        state.searchText = ""
        #expect(state.filteredDistricts.map(\.id) == ["b", "a"])
        #expect(!state.isReorderDisabled)
    }

    @Test("検索中は並べ替えモードを開始できない")
    @MainActor
    func searchPreventsReordering() async {
        let (festival, appState, _, _) = fixtures()
        var initial = HeadquarterDistrictListFeature.State(
            festival, appState: Shared(value: Optional(appState))
        )
        initial.searchText = "Alpha"
        let store = TestStore(initialState: initial) {
            HeadquarterDistrictListFeature()
        } withDependencies: { $0.installTestSpies() }

        await store.send(.reorderTapped)
        #expect(!store.state.isReordering)
        #expect(store.state.draftDistricts == nil)
        await store.finish()
    }

    @Test("並べ替えを開始して変更がなければ保存せず終了する")
    @MainActor
    func entersAndExitsUnchangedReorderMode() async {
        let (festival, appState, a, b) = fixtures()
        let initial = HeadquarterDistrictListFeature.State(
            festival, appState: Shared(value: Optional(appState))
        )
        let store = TestStore(initialState: initial) {
            HeadquarterDistrictListFeature()
        } withDependencies: { $0.installTestSpies() }

        await store.send(.reorderTapped) {
            $0.draftDistricts = [a, b]
            $0.isReordering = true
        }
        await store.send(.reorderTapped) {
            $0.isReordering = false
            $0.draftDistricts = nil
        }
        await store.finish()
    }

    @Test("一覧の並び替えは地区固有のOrderを交換し、IDは変更しない")
    @MainActor
    func movedDistrictGetsTargetPositionOrder() async {
        let (festival, appState, a, b) = fixtures()
        var initial = HeadquarterDistrictListFeature.State(
            festival, appState: Shared(value: Optional(appState))
        )
        initial.isReordering = true
        initial.draftDistricts = [a, b]
        let store = TestStore(initialState: initial) {
            HeadquarterDistrictListFeature()
        } withDependencies: { $0.installTestSpies() }

        await store.send(.districtMoved(from: IndexSet(integer: 1), to: 0)) {
            var newB = b
            newB.order = 1
            var newA = a
            newA.order = 2
            $0.draftDistricts = [newB, newA]
        }
        await store.finish()
    }

    @Test("地区選択の失敗時にローディングを解除しエラー内容を示す")
    @MainActor
    func selectedDistrictFailure() async {
        let (festival, appState, a, _) = fixtures()
        var initial = HeadquarterDistrictListFeature.State(
            festival, appState: Shared(value: Optional(appState))
        )
        initial.loadingDistrictID = a.id
        let store = TestStore(initialState: initial) {
            HeadquarterDistrictListFeature()
        } withDependencies: { $0.installTestSpies() }
        let error = AppError.be(.network("offline"))

        await store.send(.selectedReceived(.failure(error))) {
            $0.loadingDistrictID = nil
            $0.alert = AlertFeature.error(error.message)
        }
        #expect(!store.state.isLoading)
        await store.finish()
    }

    @Test("地区追加アクションは祭典IDを持つ追加画面へ遷移する")
    @MainActor
    func createTappedShowsCreationScreen() async {
        let (festival, appState, _, _) = fixtures()
        let initial = HeadquarterDistrictListFeature.State(
            festival, appState: Shared(value: Optional(appState))
        )
        let store = TestStore(initialState: initial) {
            HeadquarterDistrictListFeature()
        } withDependencies: { $0.installTestSpies() }
        store.exhaustivity = .off

        await store.send(.createTapped)

        #expect(store.state.destination?.create?.festivalId == "festival")
        await store.finish()
    }

    @Test("並べ替え保存成功時にローディングとドラフトを解除する")
    @MainActor
    func successfulReorderClearsDraft() async {
        let (festival, appState, a, b) = fixtures()
        var initial = HeadquarterDistrictListFeature.State(
            festival, appState: Shared(value: Optional(appState))
        )
        initial.draftDistricts = [b, a]
        initial.isReordering = true
        initial.isReorderingSaving = true
        let store = TestStore(initialState: initial) {
            HeadquarterDistrictListFeature()
        } withDependencies: { $0.installTestSpies() }

        await store.send(.reorderReceived(.success)) {
            $0.isReorderingSaving = false
            $0.isReordering = false
            $0.draftDistricts = nil
        }
        await store.finish()
    }
    @Test("並べ替え中の検索入力は消去され、通常の検索入力のみ保持する")
    @MainActor
    func searchBindingIsIgnoredDuringReordering() async {
        let (festival, appState, _, _) = fixtures()
        var initial = HeadquarterDistrictListFeature.State(
            festival, appState: Shared(value: Optional(appState))
        )
        initial.isReordering = true
        let store = TestStore(initialState: initial) {
            HeadquarterDistrictListFeature()
        } withDependencies: { $0.installTestSpies() }

        await store.send(.binding(.set(\.searchText, "Bravo")))
        #expect(store.state.searchText.isEmpty)
        await store.send(.binding(.set(\.isReordering, false))) {
            $0.isReordering = false
        }
        await store.send(.binding(.set(\.searchText, "Alpha"))) {
            $0.searchText = "Alpha"
        }
        #expect(store.state.filteredDistricts.map(\.id) == ["a"])
        await store.finish()
    }

    @Test("ドラフトがない移動要求は実データを変更しない")
    @MainActor
    func movementWithoutDraftDoesNothing() async {
        let (festival, appState, _, _) = fixtures()
        let store = TestStore(
            initialState: HeadquarterDistrictListFeature.State(
                festival, appState: Shared(value: Optional(appState))
            )
        ) { HeadquarterDistrictListFeature() } withDependencies: {
            $0.installTestSpies()
        }
        await store.send(.districtMoved(from: IndexSet(integer: 0), to: 1))
        #expect(store.state.draftDistricts == nil)
        #expect(store.state.districts.map(\.order) == [2, 1])
        await store.finish()
    }

    @Test("地区の取得成功では読み込みフラグを消して詳細画面へ遷移する")
    @MainActor
    func selectedDistrictSuccessOpensDetail() async {
        let (festival, appState, a, _) = fixtures()
        var initial = HeadquarterDistrictListFeature.State(
            festival, appState: Shared(value: Optional(appState))
        )
        initial.loadingDistrictID = a.id
        let store = TestStore(initialState: initial) {
            HeadquarterDistrictListFeature()
        } withDependencies: { $0.installTestSpies() }
        store.exhaustivity = .off

        await store.send(.selectedReceived(.success(a)))
        #expect(store.state.loadingDistrictID == nil)
        #expect(store.state.destination?.detail?.district.id == a.id)
        await store.finish()
    }

    @Test("並べ替えと一括出力のエラーは処理中の状態を解除する")
    @MainActor
    func reorderAndExportFailureClearFlags() async {
        let (festival, appState, a, b) = fixtures()
        let error = AppError.be(.network("service unavailable"))
        var initial = HeadquarterDistrictListFeature.State(
            festival, appState: Shared(value: Optional(appState))
        )
        initial.isReordering = true
        initial.draftDistricts = [b, a]
        initial.isReorderingSaving = true
        initial.isExportLoading = true

        let store = TestStore(initialState: initial) {
            HeadquarterDistrictListFeature()
        } withDependencies: { $0.installTestSpies() }
        await store.send(.reorderReceived(.failure(error))) {
            $0.isReorderingSaving = false
            $0.isExportLoading = false
            $0.alert = AlertFeature.error(error.message)
        }
        #expect(store.state.isReordering)
        #expect(!store.state.isLoading)
        await store.finish()

        var exportInitial = HeadquarterDistrictListFeature.State(
            festival, appState: Shared(value: Optional(appState))
        )
        exportInitial.isExportLoading = true
        let exportStore = TestStore(initialState: exportInitial) {
            HeadquarterDistrictListFeature()
        } withDependencies: { $0.installTestSpies() }
        await exportStore.send(.batchExportReceived(.failure(error))) {
            $0.isExportLoading = false
            $0.alert = AlertFeature.error(error.message)
        }
        await exportStore.finish()
    }

    @Test("空のPDF出力結果も成功として完了しフォルダを構成する")
    @MainActor
    func emptyBatchExportProducesFolder() async {
        let (festival, appState, _, _) = fixtures()
        var initial = HeadquarterDistrictListFeature.State(
            festival, appState: Shared(value: Optional(appState))
        )
        initial.isExportLoading = true
        let store = TestStore(initialState: initial) {
            HeadquarterDistrictListFeature()
        } withDependencies: { $0.installTestSpies() }
        store.exhaustivity = .off
        await store.send(.batchExportReceived(.success([])))
        #expect(!store.state.isExportLoading)
        #expect(store.state.folder != nil)
        await store.finish()
    }

    @Test("地区順序変更は差分となった地区だけSaveDistrictUseCaseに順番どおり渡す")
    @MainActor
    func savesChangedDistrictOrders() async {
        let (festival, appState, a, b) = fixtures()
        var movedA = a
        movedA.order = 2
        var movedB = b
        movedB.order = 1
        var state = HeadquarterDistrictListFeature.State(
            festival, appState: Shared<AppState?>(value: appState)
        )
        state.isReordering = true
        state.draftDistricts = [movedB, movedA]
        let spy = ListSaveDistrictSpy()
        let store = TestStore(initialState: state) {
            HeadquarterDistrictListFeature()
        } withDependencies: {
            $0.installTestSpies()
            $0[SaveDistrictUseCaseKey.self] = spy
        }

        await store.send(.reorderTapped) {
            $0.isReorderingSaving = true
        }
        await store.receive(.reorderReceived(.success)) {
            $0.isReorderingSaving = false
            $0.isReordering = false
            $0.draftDistricts = nil
        }
        #expect(await spy.ids == ["b", "a"])
        #expect(!store.state.isLoading)
        await store.finish()
    }

    @Test("並べ替え保存途中で失敗したらエラーを表示しドラフトを維持する")
    @MainActor
    func reorderFailurePreservesDraftForRetry() async {
        let (festival, appState, a, b) = fixtures()
        var movedA = a
        movedA.order = 2
        var movedB = b
        movedB.order = 1
        var state = HeadquarterDistrictListFeature.State(
            festival, appState: Shared<AppState?>(value: appState)
        )
        state.isReordering = true
        state.draftDistricts = [movedB, movedA]
        let error = AppError.be(.network("offline"))
        let spy = ListSaveDistrictSpy(error: error)
        let store = TestStore(initialState: state) {
            HeadquarterDistrictListFeature()
        } withDependencies: {
            $0.installTestSpies()
            $0[SaveDistrictUseCaseKey.self] = spy
        }

        await store.send(.reorderTapped) {
            $0.isReorderingSaving = true
        }
        await store.receive(.reorderReceived(.failure(error))) {
            $0.isReorderingSaving = false
            $0.alert = AlertFeature.error(error.message)
        }
        #expect(store.state.isReordering)
        #expect(store.state.draftDistricts == [movedB, movedA])
        #expect(await spy.ids == ["b"])
        await store.finish()
    }

    @Test("地区タップで指定地区の初期読込をUseCaseへ依頼し詳細画面へ遷移する")
    @MainActor
    func selectedDistrictInvokesLoadUseCase() async {
        let (festival, appState, a, _) = fixtures()
        let spy = DistrictLoadSpy(response: LaunchDistrictPack(
            performances: [], routes: [], points: [], passages: [], currentRouteId: nil
        ))
        let store = TestStore(
            initialState: HeadquarterDistrictListFeature.State(
                festival, appState: Shared<AppState?>(value: appState)
            )
        ) {
            HeadquarterDistrictListFeature()
        } withDependencies: {
            $0.installTestSpies()
            $0[LoadDistrictStateUseCaseKey.self] = spy
        }
        store.exhaustivity = .off

        await store.send(.selected(a))
        await store.receive(.selectedReceived(.success(a)))
        #expect(store.state.loadingDistrictID == nil)
        #expect(store.state.destination?.detail?.district.id == a.id)
        await store.finish()
    }

}

private actor ListSaveDistrictSpy: SaveDistrictUseCaseProtocol {
    private(set) var ids: [District.ID] = []
    let error: AppError?

    init(error: AppError? = nil) { self.error = error }

    func callAsFunction(district: District, appState: Shared<AppState?>) async throws -> District {
        ids.append(district.id)
        if let error { throw error }
        return district
    }
}
