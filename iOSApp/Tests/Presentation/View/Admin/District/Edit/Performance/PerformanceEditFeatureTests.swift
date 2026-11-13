import ComposableArchitecture
import Shared
import Testing
@testable import iOSApp

struct PerformanceEditFeatureTests {
    @Test("既存の余興を指定したら編集モードで元の値を保持する")
    func initializesInEditMode() {
        let item = Performance(id: "performance", name: "Dance", districtId: "district")
        let state = PerformanceEditFeature.State(item: item)

        #expect(state.mode == .edit)
        #expect(state.item == item)
        #expect(state.alert == nil)
    }

    @Test("地区IDから新規登録を開くと空の余興を生成する")
    func initializesInCreateMode() {
        let state = PerformanceEditFeature.State(districtId: "district")

        #expect(state.mode == .create)
        #expect(state.item.districtId == "district")
        #expect(!state.item.id.isEmpty)
        #expect(state.alert == nil)
    }

    @Test("作成モードでは削除確認を表示しない")
    @MainActor
    func deleteInCreateModeIsIgnored() async {
        let store = TestStore(initialState: PerformanceEditFeature.State(
            districtId: "district"
        )) {
            PerformanceEditFeature()
        }

        await store.send(.deleteTapped)
        #expect(store.state.alert == nil)
        await store.finish()
    }

    @Test("既存余興の削除は取り消し可能な確認アラートを提示する")
    @MainActor
    func deleteInEditModePresentsConfirmation() async {
        let item = Performance(id: "performance", name: "Dance", districtId: "district")
        let store = TestStore(initialState: PerformanceEditFeature.State(item: item)) {
            PerformanceEditFeature()
        }

        await store.send(.deleteTapped) {
            $0.alert = AlertFeature.delete(
                "このデータを削除してもよろしいですか。元の画面で保存を選択するとこのデータは削除され、操作を取り戻すことはできません。"
            )
        }
        await store.finish()
    }

    @Test("余興名のBindingは編集中のモデルにだけ反映される")
    @MainActor
    func bindingEditsNameWithoutChangingId() async {
        let item = Performance(id: "performance", name: "Before", districtId: "district")
        let store = TestStore(initialState: PerformanceEditFeature.State(item: item)) {
            PerformanceEditFeature()
        }

        await store.send(.binding(.set(\.item.name, "After"))) {
            $0.item.name = "After"
        }
        #expect(store.state.item.id == "performance")
        await store.finish()
    }

    @Test("編集完了は親画面へ渡す値を保持する")
    @MainActor
    func doneDoesNotChangeData() async {
        let item = Performance(id: "performance", name: "Before", districtId: "district")
        let store = TestStore(initialState: PerformanceEditFeature.State(item: item)) {
            PerformanceEditFeature()
        }

        await store.send(.doneTapped)
        #expect(store.state.item == item)
        await store.finish()
    }
}
