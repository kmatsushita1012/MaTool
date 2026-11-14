import ComposableArchitecture
import MapKit
import Shared
import Testing
@testable import iOSApp

struct HazardSectionFeatureTests {
    private let first = Coordinate(latitude: 35.0, longitude: 139.0)
    private let second = Coordinate(latitude: 35.1, longitude: 139.1)
    private let middle = Coordinate(latitude: 35.05, longitude: 139.05)

    private func map() -> MKCoordinateRegion {
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 35, longitude: 139),
            span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
        )
    }

    private func item(coordinates: [Coordinate] = []) -> HazardSection {
        HazardSection(
            id: "hazard", title: "危険区間",
            festivalId: "festival", coordinates: coordinates
        )
    }

    @Test("空の区間編集はタイトル未入力・2地点未満として不正")
    func initialNewStateHasNoCoordinates() {
        let state = HazardSectionFeature.State(mapRegion: map(), festivalId: "festival")

        #expect(state.mode == .add)
        #expect(state.item.festivalId == "festival")
        #expect(state.item.coordinates.isEmpty)
        #expect(!state.isValid)
        #expect(state.alert == nil)
    }

    @Test("2地点とタイトルが両方ある場合だけ保存条件を満たす")
    func validationRequiresTitleAndTwoPoints() {
        let emptyTitle = HazardSection(
            id: "hazard", title: "",
            festivalId: "festival", coordinates: [first, second]
        )
        let singlePoint = item(coordinates: [first])
        let complete = item(coordinates: [first, second])
        #expect(!HazardSectionFeature.State(emptyTitle, mapRegion: map()).isValid)
        #expect(!HazardSectionFeature.State(singlePoint, mapRegion: map()).isValid)
        #expect(HazardSectionFeature.State(complete, mapRegion: map()).isValid)
    }

    @Test("通常モードで地図を長押しすると順番通りに地点を追記する")
    @MainActor
    func longPressAppendsCoordinates() async {
        let store = TestStore(initialState: HazardSectionFeature.State(
            item(), mapRegion: map()
        )) { HazardSectionFeature() }
        store.exhaustivity = .off

        await store.send(.mapLongPressed(first))
        await store.send(.mapLongPressed(second))

        #expect(store.state.item.coordinates == [first, second])
        #expect(store.state.mode == .add)
        #expect(store.state.isValid)
        await store.finish()
    }

    @Test("先頭の前へ挿入するモードで長押しすると新地点が先頭に入る")
    @MainActor
    func insertsBeforeSelectedCoordinate() async {
        let store = TestStore(initialState: HazardSectionFeature.State(
            item(coordinates: [first, second]), mapRegion: map()
        )) { HazardSectionFeature() }
        store.exhaustivity = .off

        await store.send(.insertBeforeTapped(first))
        #expect(store.state.mode == .insertBefore(0))
        await store.send(.mapLongPressed(middle))

        #expect(store.state.item.coordinates == [middle, first, second])
        #expect(store.state.mode == .add)
        await store.finish()
    }

    @Test("最後の地点の後に新地点を挿入する")
    @MainActor
    func insertsAfterSelectedCoordinate() async {
        let store = TestStore(initialState: HazardSectionFeature.State(
            item(coordinates: [first, second]), mapRegion: map()
        )) { HazardSectionFeature() }
        store.exhaustivity = .off

        await store.send(.insertAfterTapped(second))
        #expect(store.state.mode == .insertAfter(1))
        await store.send(.mapLongPressed(middle))

        #expect(store.state.item.coordinates == [first, second, middle])
        #expect(store.state.mode == .add)
        await store.finish()
    }

    @Test("リストにない地点の挿入メニューを押してもモードは変わらない")
    @MainActor
    func unknownCoordinateIsNotAnInsertionAnchor() async {
        let store = TestStore(initialState: HazardSectionFeature.State(
            item(coordinates: [first, second]), mapRegion: map()
        )) { HazardSectionFeature() }

        await store.send(.insertBeforeTapped(middle))
        await store.send(.insertAfterTapped(middle))

        #expect(store.state.mode == .add)
        await store.finish()
    }

    @Test("同じ地点が複数回含まれていても削除はすべて除去する")
    @MainActor
    func removeDeletesAllMatchingCoordinates() async {
        let store = TestStore(initialState: HazardSectionFeature.State(
            item(coordinates: [first, second, first]), mapRegion: map()
        )) { HazardSectionFeature() }
        store.exhaustivity = .off

        await store.send(.removeTapped(first))

        #expect(store.state.item.coordinates == [second])
        #expect(store.state.mode == .add)
        await store.finish()
    }

    @Test("UndoとRedoは直近の操作を取消・復元する")
    @MainActor
    func undoAndRedoRestorePreviousCoordinates() async {
        let store = TestStore(initialState: HazardSectionFeature.State(
            item(coordinates: [first]), mapRegion: map()
        )) { HazardSectionFeature() }
        store.exhaustivity = .off

        await store.send(.mapLongPressed(second))
        #expect(store.state.item.coordinates == [first, second])
        await store.send(.undoTapped)
        #expect(store.state.item.coordinates == [first])
        await store.send(.redoTapped)
        #expect(store.state.item.coordinates == [first, second])
        #expect(store.state.mode == .add)
        await store.finish()
    }

    @Test("一括クリアは全座標と挿入モードを解除する")
    @MainActor
    func clearRemovesAllCoordinates() async {
        let store = TestStore(initialState: HazardSectionFeature.State(
            item(coordinates: [first, second]), mapRegion: map()
        )) { HazardSectionFeature() }
        store.exhaustivity = .off

        await store.send(.insertAfterTapped(first))
        await store.send(.clearTapped)

        #expect(store.state.item.coordinates.isEmpty)
        #expect(store.state.mode == .add)
        await store.finish()
    }

    @Test("ピン選択は対応する地点を保持しメニュー終了で解除する")
    @MainActor
    func selectedPinIsClearedWhenMenuCloses() async {
        let store = TestStore(initialState: HazardSectionFeature.State(
            item(coordinates: [first, second]), mapRegion: map()
        )) { HazardSectionFeature() }

        await store.send(.pinSelected(second)) {
            $0.selectedPin = second
        }
        await store.send(.menuClosed) {
            $0.selectedPin = nil
        }
        await store.finish()
    }

    @Test("タイトルまたは地点不足の完了は詳細なバリデーションアラートを提示する")
    @MainActor
    func invalidDonePresentsValidationMessage() async {
        let store = TestStore(initialState: HazardSectionFeature.State(
            item(coordinates: [first]), mapRegion: map()
        )) { HazardSectionFeature() }

        await store.send(.doneTapped) {
            $0.alert = AlertFeature.error(
                "タイトルを1文字以上、地点を2つ以上入力してください。"
            )
        }
        await store.finish()
    }

    @Test("完成した危険区間の完了はモデルを変更せず親側へ委譲する")
    @MainActor
    func validDoneRetainsModel() async {
        let completed = item(coordinates: [first, second])
        let store = TestStore(initialState: HazardSectionFeature.State(
            completed, mapRegion: map()
        )) { HazardSectionFeature() }

        await store.send(.doneTapped)
        await store.send(.deleteTapped)

        #expect(store.state.item == completed)
        #expect(store.state.alert == nil)
        await store.finish()
    }
}
