import ComposableArchitecture
import MapKit
import Shared
import Testing
@testable import iOSApp

struct MapCoordinatePickerFeatureTests {
    private let first = Coordinate(latitude: 35.0, longitude: 139.0)
    private let second = Coordinate(latitude: 35.5, longitude: 139.5)

    @Test("既存地点の編集は現在の座標を選択し地図の中心に設定する")
    func initialBaseCentersMap() {
        let state = MapCoordinatePickerFeature.State(
            coordinate: first,
            regionOrigin: first,
            title: "位置を選択"
        )

        #expect(state.coordinate == first)
        #expect(state.region?.center.latitude == first.latitude)
        #expect(state.region?.center.longitude == first.longitude)
    }

    @Test("新規地点は初期座標を選択せず指定した中心に地図を表示する")
    func initialOriginDoesNotSelectLocation() {
        let state = MapCoordinatePickerFeature.State(
            coordinate: nil,
            regionOrigin: second,
            title: "位置を選択"
        )

        #expect(state.coordinate == nil)
        #expect(state.region?.center.latitude == second.latitude)
        #expect(state.region?.center.longitude == second.longitude)
    }

    @Test("地図タップは選択中の地点を新しい座標に置き換える")
    @MainActor
    func mapTapUpdatesSelectedCoordinate() async {
        let store = TestStore(initialState: MapCoordinatePickerFeature.State(
            coordinate: first,
            regionOrigin: first,
            title: "位置を選択"
        )) {
            MapCoordinatePickerFeature()
        }

        await store.send(.mapTapped(second)) {
            $0.coordinate = second
        }
        #expect(store.state.region?.center.latitude == first.latitude)
        await store.finish()
    }

    @Test("地点のクリアは地図の表示範囲を維持したまま選択だけ解除する")
    @MainActor
    func clearPreservesMapRegion() async {
        let initial = MapCoordinatePickerFeature.State(
            coordinate: first,
            regionOrigin: first,
            title: "位置を選択"
        )
        let store = TestStore(initialState: initial) { MapCoordinatePickerFeature() }

        await store.send(.clearTapped) { $0.coordinate = nil }

        #expect(store.state.region == initial.region)
        await store.finish()
    }

    @Test("完了ボタンは選択済みの座標を親画面用に保持する")
    @MainActor
    func doneDoesNotChangeSelectedCoordinate() async {
        let store = TestStore(initialState: MapCoordinatePickerFeature.State(
            coordinate: first,
            regionOrigin: first,
            title: "位置を選択"
        )) {
            MapCoordinatePickerFeature()
        }

        await store.send(.doneTapped)
        #expect(store.state.coordinate == first)
        await store.finish()
    }
}
