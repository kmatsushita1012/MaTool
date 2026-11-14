import ComposableArchitecture
import Shared
import Testing
@testable import iOSApp

struct PointEditFeatureTests {
    private let coordinate = Coordinate(latitude: 35, longitude: 139)

    private func point(
        checkpoint: String? = nil,
        performance: String? = nil,
        anchor: Anchor? = nil,
        time: SimpleTime? = nil
    ) -> Point {
        Point(
            id: "point", routeId: "route", coordinate: coordinate,
            time: time, checkpointId: checkpoint,
            performanceId: performance, anchor: anchor
        )
    }

    private func state(_ point: Point) -> PointEditFeature.State {
        .init(
            point, districtId: "district",
            appState: Shared(value: Optional(AppStateFixture.state()))
        )
    }

    @Test("Checkpoint・余興・始点・終点・休憩・無指定の6種類を判定する")
    func identifiesAllPointTypes() {
        let time = SimpleTime(hour: 9, minute: 0)
        #expect(PointEditFeature.PointType.allCases.count == 6)
        #expect(state(point(checkpoint: "cp", time: time)).pointType == .checkpoint)
        #expect(state(point(performance: "perf", time: time)).pointType == .performance)
        #expect(state(point(anchor: .start, time: time)).pointType == .start)
        #expect(state(point(anchor: .end, time: time)).pointType == .end)
        #expect(state(point(anchor: .rest, time: time)).pointType == .rest)
        #expect(state(point()).pointType == .none)
    }

    @Test("チェックポイントと余興がない地区では候補から外す")
    func filtersUnavailablePointTypes() {
        let normal = state(point())
        #expect(normal.validTypes == [.start, .end, .rest, .none])

        let checkpoint = state(point(checkpoint: "cp"))
        #expect(checkpoint.validTypes.contains(.checkpoint))
        #expect(!checkpoint.validTypes.contains(.performance))

        let performance = state(point(performance: "perf"))
        #expect(performance.validTypes.contains(.performance))
        #expect(!performance.validTypes.contains(.checkpoint))
    }

    @Test("地区の余興一覧が利用可能なら余興タイプを選択肢に出す")
    func showsPerformanceTypeForCurrentDistrict() {
        let performance = Performance(id: "perf", districtId: "district")
        let appState = AppStateFixture.state(performances: [performance])
        let selection = PointEditFeature.State(
            point(), districtId: "district", appState: Shared(value: Optional(appState))
        )
        let foreignSelection = PointEditFeature.State(
            point(), districtId: "foreign", appState: Shared(value: Optional(appState))
        )

        #expect(selection.validTypes.contains(.performance))
        #expect(!foreignSelection.validTypes.contains(.performance))
        #expect(selection.performances == [performance])
        #expect(foreignSelection.performances.isEmpty)
    }

    @Test("登録済みの交差点を現在の選択中の地点から参照できる")
    func selectsCheckpointById() {
        let checkpoint = Checkpoint(id: "cp", name: "交差点", festivalId: "festival")
        let pack = LaunchFestivalPack(
            festival: AppStateFixture.festival(),
            districts: [AppStateFixture.district()],
            periods: [AppStateFixture.period()],
            locations: [], checkpoints: [checkpoint],
            hazardSections: []
        )
        let state = PointEditFeature.State(
            point(checkpoint: "cp"),
            districtId: "district",
            appState: Shared(value: Optional(AppState(festivalPack: pack)))
        )

        #expect(state.validTypes.contains(.checkpoint))
        #expect(state.selectedCheckpoint == checkpoint)
        #expect(state.selectedPerformance == nil)
    }

    @Test("現在の地区の余興を選択済みIDから参照できる")
    func selectsPerformanceById() {
        let performance = Performance(id: "perf", name: "Dance", districtId: "district")
        let appState = AppStateFixture.state(performances: [performance])
        let state = PointEditFeature.State(
            point(performance: "perf"),
            districtId: "district", appState: Shared(value: Optional(appState))
        )

        #expect(state.selectedPerformance == performance)
        #expect(state.selectedCheckpoint == nil)
    }

    @Test("始点を選ぶと他の関係IDを消して到着時刻を補完する")
    @MainActor
    func selectingStartRemovesOtherRelations() async {
        let store = TestStore(initialState: state(point(checkpoint: "cp"))) {
            PointEditFeature()
        }
        store.exhaustivity = .off

        await store.send(.binding(.set(\.pointType, .start)))

        #expect(store.state.point.anchor == .start)
        #expect(store.state.point.checkpointId == nil)
        #expect(store.state.point.performanceId == nil)
        #expect(store.state.point.time != nil)
        await store.finish()
    }

    @Test("終点・休憩の選択も時刻とAnchorを自動設定する")
    @MainActor
    func selectingAnchorsSetsTimeWhenMissing() async {
        let store = TestStore(initialState: state(point())) {
            PointEditFeature()
        }
        store.exhaustivity = .off

        await store.send(.binding(.set(\.pointType, .end)))
        #expect(store.state.point.anchor == .end)
        #expect(store.state.point.time != nil)

        await store.send(.binding(.set(\.pointType, .rest)))
        #expect(store.state.point.anchor == .rest)
        #expect(store.state.point.time != nil)
        await store.finish()
    }

    @Test("タイプなしに戻すと関連IDと時刻をすべて消去する")
    @MainActor
    func selectingNoneClearsAllMetadata() async {
        let store = TestStore(initialState: state(
            point(anchor: .start, time: SimpleTime(hour: 9, minute: 0))
        )) {
            PointEditFeature()
        }
        store.exhaustivity = .off

        await store.send(.binding(.set(\.pointType, .none)))

        #expect(store.state.point.anchor == nil)
        #expect(store.state.point.checkpointId == nil)
        #expect(store.state.point.performanceId == nil)
        #expect(store.state.point.time == nil)
        await store.finish()
    }

    @Test("交差点が未選択のまま完了や移動すると入力エラーを表示する")
    @MainActor
    func missingCheckpointReferenceShowsValidationAlert() async {
        let mutatingPoint = point()
        var initial = state(mutatingPoint)
        initial.pointType = .checkpoint
        let store = TestStore(initialState: initial) { PointEditFeature() }
        store.exhaustivity = .off

        await store.send(.doneTapped)
        #expect(store.state.alert != nil)
        await store.finish()
    }

    @Test("有効なアンカー付き地点は編集完了でアラートを出さない")
    @MainActor
    func validPointAllowsDone() async {
        let store = TestStore(initialState: state(
            point(anchor: .start, time: SimpleTime(hour: 9, minute: 0))
        )) { PointEditFeature() }

        await store.send(.doneTapped)
        await store.send(.moveTapped)
        await store.send(.insertBeforeTapped)
        await store.send(.insertAfterTapped)
        await store.send(.deleteTapped)

        #expect(store.state.alert == nil)
        await store.finish()
    }

    @Test("ポイントに余興IDがなく余興タイプのみが選ばれていればエラーを返す")
    func validatesSelectedPerformanceReference() {
        var state = state(point())
        state.pointType = .performance
        #expect(throws: Point.Error.self) { try state.validate() }
    }

    @Test("交差点に時刻が指定されない場合はモデル自身の入力検証で拒否する")
    func rejectsCheckpointWithoutTimestamp() {
        #expect(throws: Point.Error.self) {
            try state(point(checkpoint: "cp")).validate()
        }
    }
}
