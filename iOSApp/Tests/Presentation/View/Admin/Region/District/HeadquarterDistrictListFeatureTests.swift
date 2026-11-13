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
}
