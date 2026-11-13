import ComposableArchitecture
import MapKit
import Shared
import Testing
@testable import iOSApp

struct DistrictAreaEditFeatureTests {
    private let origin = Coordinate(latitude: 35.0, longitude: 139.0)
    private let first = Coordinate(latitude: 35.1, longitude: 139.1)
    private let second = Coordinate(latitude: 35.2, longitude: 139.2)

    @Test("地区ポリゴンの初期化は既存地点と地図中心を保持する")
    func initialStatePreservesCoordinates() {
        let state = DistrictAreaEditFeature.State(
            coordinates: [first], origin: origin
        )

        #expect(state.coordinates == [first])
        #expect(state.region?.center.latitude == origin.latitude)
        #expect(state.region?.center.longitude == origin.longitude)
    }

    @Test("地図へのタップは既存ポリゴンを保持して新しい地点を追記する")
    @MainActor
    func mapTapAppendsCoordinatesInOrder() async {
        let initial = DistrictAreaEditFeature.State(
            coordinates: [first], origin: origin
        )
        let store = TestStore(initialState: initial) { DistrictAreaEditFeature() }

        await store.send(.mapTapped(second)) {
            $0.coordinates = [first, second]
        }
        #expect(store.state.region == initial.region)
        await store.finish()
    }

    @Test("Undoは最後の地点だけを取り除く")
    @MainActor
    func undoRemovesLastCoordinate() async {
        let store = TestStore(initialState: DistrictAreaEditFeature.State(
            coordinates: [first, second], origin: origin
        )) { DistrictAreaEditFeature() }

        await store.send(.undoTapped) {
            $0.coordinates = [first]
        }
        await store.send(.undoTapped) {
            $0.coordinates = []
        }
        await store.finish()
    }

    @Test("空のポリゴンでUndoしてもクラッシュや負数Indexは発生しない")
    @MainActor
    func undoEmptyIsNoOp() async {
        let store = TestStore(initialState: DistrictAreaEditFeature.State(
            coordinates: [], origin: origin
        )) { DistrictAreaEditFeature() }

        await store.send(.undoTapped)
        #expect(store.state.coordinates.isEmpty)
        await store.finish()
    }

    @Test("地点配列のBindingは指定した新しい内容を保持する")
    @MainActor
    func bindingCanReplaceCoordinates() async {
        let store = TestStore(initialState: DistrictAreaEditFeature.State(
            coordinates: [], origin: origin
        )) { DistrictAreaEditFeature() }

        await store.send(.binding(.set(\.coordinates, [first, second]))) {
            $0.coordinates = [first, second]
        }
        await store.finish()
    }

    @Test("完了操作はポリゴンを変更せず親画面の保存に委譲する")
    @MainActor
    func doneKeepsEditedPolygon() async {
        let store = TestStore(initialState: DistrictAreaEditFeature.State(
            coordinates: [first, second], origin: origin
        )) { DistrictAreaEditFeature() }

        await store.send(.doneTapped)
        #expect(store.state.coordinates == [first, second])
        await store.finish()
    }
}
