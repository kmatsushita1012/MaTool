import ComposableArchitecture
import Shared
import Testing
@testable import iOSApp

struct CheckpointEditFeatureTests {
    @Test("選択されたチェックポイントと編集画面タイトルを初期状態に保持する")
    func stateKeepsCheckpointAndTitle() {
        let checkpoint = Checkpoint(id: "checkpoint", name: "Rest Point", festivalId: "festival")
        let state = CheckpointEditFeature.State(title: "Edit checkpoint", item: checkpoint)

        #expect(state.title == "Edit checkpoint")
        #expect(state.item == checkpoint)
    }

    @Test("チェックポイント名を編集しても識別子と祭典の紐付けは不変")
    @MainActor
    func bindingChangesOnlyCheckpointTitle() async {
        let checkpoint = Checkpoint(id: "checkpoint", name: "Before", festivalId: "festival")
        let store = TestStore(initialState: .init(title: "Edit", item: checkpoint)) {
            CheckpointEditFeature()
        }

        await store.send(.binding(.set(\.item.name, "After"))) {
            $0.item.name = "After"
        }
        #expect(store.state.item.id == "checkpoint")
        #expect(store.state.item.festivalId == "festival")
        await store.finish()
    }

    @Test("編集完了は親Reducerが保存するため元の状態を維持する")
    @MainActor
    func doneDoesNotSaveOrModifyLocally() async {
        let checkpoint = Checkpoint(id: "checkpoint", name: "Before", festivalId: "festival")
        let store = TestStore(initialState: .init(title: "Edit", item: checkpoint)) {
            CheckpointEditFeature()
        }

        await store.send(.doneTapped)
        #expect(store.state.item == checkpoint)
        await store.finish()
    }

    @Test("削除タップは親Reducerの確認に委譲してモデルを消さない")
    @MainActor
    func deleteKeepsModelForParent() async {
        let checkpoint = Checkpoint(id: "checkpoint", name: "Before", festivalId: "festival")
        let store = TestStore(initialState: .init(title: "Edit", item: checkpoint)) {
            CheckpointEditFeature()
        }

        await store.send(.deleteTapped)
        #expect(store.state.item == checkpoint)
        await store.finish()
    }
}
