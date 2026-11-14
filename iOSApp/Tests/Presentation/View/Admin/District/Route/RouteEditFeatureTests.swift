import ComposableArchitecture
import Shared
import Testing
@testable import iOSApp

struct RouteEditFeatureTests {
    @Test("過去のRouteをコピーすると別IDの新規RouteとPoint、Passageになる")
    @MainActor
    func 過去Routeのコピーで新しいEntityを作る() async throws {
        let festival = Festival(
            id: "festival",
            name: "Festival",
            subname: "Festival",
            base: Coordinate(latitude: 35, longitude: 139)
        )
        let district = District(id: "district", name: "District", festivalId: festival.id)
        let currentPeriod = Period(
            id: "current-period",
            festivalId: festival.id,
            date: SimpleDate(year: 2026, month: 10, day: 3),
            start: SimpleTime(hour: 9, minute: 0),
            end: SimpleTime(hour: 17, minute: 0)
        )
        let pastPeriod = Period(
            id: "past-period",
            festivalId: festival.id,
            date: SimpleDate(year: 2025, month: 10, day: 4),
            start: SimpleTime(hour: 9, minute: 0),
            end: SimpleTime(hour: 17, minute: 0)
        )
        let sourceRoute = Route(
            id: "source-route",
            districtId: district.id,
            periodId: pastPeriod.id,
            visibility: .admin,
            description: "source description"
        )
        let sourcePack = RoutePack(
            route: sourceRoute,
            points: [
                Point(
                    id: "source-start",
                    routeId: sourceRoute.id,
                    coordinate: Coordinate(latitude: 35, longitude: 139),
                    time: SimpleTime(hour: 9, minute: 0),
                    anchor: .start,
                    index: 0
                ),
                Point(
                    id: "source-end",
                    routeId: sourceRoute.id,
                    coordinate: Coordinate(latitude: 35.1, longitude: 139.1),
                    time: SimpleTime(hour: 10, minute: 0),
                    anchor: .end,
                    index: 1
                )
            ],
            passages: [
                RoutePassage(id: "source-passage", routeId: sourceRoute.id, districtId: district.id, order: 0)
            ]
        )
        let editedRoute = Route(id: "edited-route", districtId: district.id, periodId: currentPeriod.id)
        let festivalState = FestivalState(
            LaunchFestivalPack(
                festival: festival,
                year: 2026,
                districts: [district],
                periods: [currentPeriod],
                locations: [],
                checkpoints: [],
                hazardSections: []
            )
        )
        let districtState = DistrictState(
            districtId: district.id,
            pack: LaunchDistrictPack(
                performances: [],
                routes: [editedRoute],
                points: [],
                passages: [],
                currentRouteId: editedRoute.id
            )
        )
        let appState = Shared<AppState?>(value: AppState(
            festivalState: festivalState,
            districtState: districtState,
            routeState: RouteState(route: editedRoute, points: [], passages: [])
        ))
        let initialState = try RouteEditFeature.State(mode: .update, route: editedRoute, appState: appState)
        let store = TestStore(initialState: initialState) {
            RouteEditFeature()
        } withDependencies: {
            $0.installTestSpies()
            $0[FetchRoutePackUseCaseKey.self] = FetchRoutePackUseCaseSpy(pack: sourcePack)
        }
        store.exhaustivity = .off

        await store.send(.sourceSelected(RouteEntry(period: pastPeriod, route: sourceRoute)))
        await store.receive(.copyPrepared(.success(sourcePack)))

        let copiedRoute = store.state.route
        #expect(store.state.mode == .create)
        #expect(copiedRoute.id != editedRoute.id)
        #expect(copiedRoute.id != sourceRoute.id)
        #expect(copiedRoute.districtId == district.id)
        #expect(copiedRoute.periodId == currentPeriod.id)
        #expect(copiedRoute.visibility == sourceRoute.visibility)
        #expect(copiedRoute.description == sourceRoute.description)
        #expect(store.state.points.map(\.id).allSatisfy { !sourcePack.points.map(\.id).contains($0) })
        #expect(store.state.points.allSatisfy { $0.routeId == copiedRoute.id })
        #expect(store.state.points.map(\.index) == [0, 1])
        #expect(store.state.passages.map(\.id) != sourcePack.passages.map(\.id))
        #expect(store.state.passages.allSatisfy { $0.routeId == copiedRoute.id })
        await store.finish()
    }
    @Test("新規・更新・プレビューの各モードで保存/削除可否とボタン名を区別する")
    func modeControlsEditingAndTitles() throws {
        var state = try makeState(mode: .create)
        #expect(state.isSaveable)
        #expect(!state.isDeleteable)
        #expect(state.title == "新規作成")
        #expect(state.saveButtonTitle == "保存")
        #expect(!state.isLoading)
        #expect(!state.isHistoryLoading)
        #expect(!state.isSourceLoading)
        #expect(!state.isExportLoading)

        state.mode = .update
        state.loadingAction = .save
        #expect(state.isSaveable)
        #expect(state.isDeleteable)
        #expect(state.isSaving)
        #expect(state.isLoading)
        state.loadingAction = .delete
        #expect(state.isDeleting)
        state.loadingAction = .history
        #expect(state.isHistoryLoading)
        state.loadingAction = .source
        #expect(state.isSourceLoading)
        state.loadingAction = .export
        #expect(state.isExportLoading)

        state.mode = .preview
        #expect(!state.isSaveable)
        #expect(!state.isDeleteable)
        #expect(state.title == "確認と修正")
        #expect(state.saveButtonTitle == "修正")
        #expect(!state.isPartialEnable)
        state.tab = .edit
        #expect(state.isPartialEnable)
        #expect(!state.canShowDistrictAreaOverlay)
    }

    @Test("初期State生成で必要な期間や地区状態が欠落していれば編集しない")
    func missingRouteStateIsRejected() {
        let route = AppStateFixture.route()
        let appState = Shared<AppState?>(value: AppStateFixture.state())
        #expect(throws: PresentationError.self) {
            _ = try RouteEditFeature.State(mode: .update, route: route, appState: appState)
        }
        #expect(throws: PresentationError.self) {
            _ = try RouteEditFeature.State(mode: .create, route: route, appState: Shared(value: nil))
        }
    }

    @Test("経路上のロングタップは新しい点を追加し地図座標を保持する")
    @MainActor
    func mapLongPressAddsPoint() async throws {
        let store = TestStore(initialState: try makeState(mode: .create)) {
            RouteEditFeature()
        } withDependencies: { $0.installTestSpies() }
        store.exhaustivity = .off
        let coordinate = Coordinate(latitude: 35.1, longitude: 139.2)

        await store.send(.mapLongPressed(coordinate))
        #expect(store.state.points.count == 1)
        #expect(store.state.points[0].coordinate == coordinate)
        #expect(store.state.points[0].routeId == store.state.route.id)
        await store.finish()
    }

    @Test("移動モードは既存点の座標だけを更新し完了時に追加モードへ戻す")
    @MainActor
    func movingPointUpdatesPositionWithoutNewID() async throws {
        let point = Point(id: "one", routeId: "route",
                          coordinate: Coordinate(latitude: 35, longitude: 139))
        var state = try makeState(mode: .create, points: [point])
        state.operation = .move(0)
        let store = TestStore(initialState: state) {
            RouteEditFeature()
        } withDependencies: { $0.installTestSpies() }
        store.exhaustivity = .off

        let target = Coordinate(latitude: 35.5, longitude: 139.5)
        await store.send(.mapLongPressed(target))
        #expect(store.state.points.count == 1)
        #expect(store.state.points[0].id == "one")
        #expect(store.state.points[0].coordinate == target)
        #expect(store.state.operation == .add)
        await store.finish()
    }

    @Test("不正な移動インデックスは範囲外アクセスを起こさず状態を維持する")
    @MainActor
    func invalidMoveIndexIsIgnored() async throws {
        var state = try makeState(mode: .create)
        state.operation = .move(-1)
        let store = TestStore(initialState: state) {
            RouteEditFeature()
        } withDependencies: { $0.installTestSpies() }
        await store.send(.mapLongPressed(Coordinate(latitude: 35, longitude: 139)))
        #expect(store.state.operation == .move(-1))
        #expect(store.state.points.isEmpty)
        await store.finish()
    }

    @Test("途中挿入は既存点を保持して選択位置に新規点を作る")
    @MainActor
    func insertingPointBetweenExistingPoints() async throws {
        let first = Point(id: "first", routeId: "route",
                          coordinate: Coordinate(latitude: 35, longitude: 139))
        let last = Point(id: "last", routeId: "route",
                         coordinate: Coordinate(latitude: 36, longitude: 140))
        var state = try makeState(mode: .create, points: [first, last])
        state.operation = .insert(1)
        let store = TestStore(initialState: state) {
            RouteEditFeature()
        } withDependencies: { $0.installTestSpies() }
        store.exhaustivity = .off
        await store.send(.mapLongPressed(Coordinate(latitude: 35.5, longitude: 139.5)))
        #expect(store.state.points.count == 3)
        #expect(store.state.points.map(\.id).first == "first")
        #expect(store.state.points.map(\.id).last == "last")
        #expect(store.state.points[1].coordinate == Coordinate(latitude: 35.5, longitude: 139.5))
        #expect(store.state.operation == .add)
        await store.finish()
    }

    @Test("不正な挿入インデックスは新しい点を作らない")
    @MainActor
    func invalidInsertIndexIsIgnored() async throws {
        var state = try makeState(mode: .create)
        state.operation = .insert(2)
        let store = TestStore(initialState: state) {
            RouteEditFeature()
        } withDependencies: { $0.installTestSpies() }
        await store.send(.mapLongPressed(Coordinate(latitude: 35, longitude: 139)))
        #expect(store.state.points.isEmpty)
        #expect(store.state.operation == .insert(2))
        await store.finish()
    }

    @Test("経路選択履歴の取得成功と失敗は別々の遷移になる")
    @MainActor
    func routeHistoryResultsAreHandled() async throws {
        var state = try makeState(mode: .update)
        state.loadingAction = .history
        let store = TestStore(initialState: state) {
            RouteEditFeature()
        } withDependencies: { $0.installTestSpies() }
        await store.send(.historyPrepared(.success([]))) {
            $0.loadingAction = nil
            $0.destination = .history([])
        }
        #expect(store.state.destination?.id == "history")
        await store.finish()

        state.loadingAction = .history
        let failing = TestStore(initialState: state) {
            RouteEditFeature()
        } withDependencies: { $0.installTestSpies() }
        failing.exhaustivity = .off
        await failing.send(.historyPrepared(.failure(.be(.network("offline")))))
        #expect(failing.state.loadingAction == nil)
        #expect(failing.state.alert != nil)
        await failing.finish()
    }

    @Test("部分出力で描画範囲が未指定なら非同期の画像作成は開始しない")
    @MainActor
    func partialExportRequiresMapSize() async throws {
        let store = TestStore(initialState: try makeState(mode: .update)) {
            RouteEditFeature()
        } withDependencies: { $0.installTestSpies() }
        store.exhaustivity = .off
        await store.send(.partialTapped)
        #expect(store.state.loadingAction == nil)
        #expect(store.state.alert != nil)
        await store.finish()
    }

    @Test("新規作成モードの削除ボタンは拒否し既存経路なら削除確認を出す")
    @MainActor
    func deleteRequiresExistingRoute() async throws {
        let newStore = TestStore(initialState: try makeState(mode: .create)) {
            RouteEditFeature()
        } withDependencies: { $0.installTestSpies() }
        newStore.exhaustivity = .off
        await newStore.send(.deleteTapped)
        #expect(newStore.state.alert != nil)
        await newStore.finish()

        let existingStore = TestStore(initialState: try makeState(mode: .update)) {
            RouteEditFeature()
        } withDependencies: { $0.installTestSpies() }
        existingStore.exhaustivity = .off
        await existingStore.send(.deleteTapped)
        #expect(existingStore.state.alert?.delete != nil)
        await existingStore.finish()
    }

    @Test("通過町の追加・挿入位置選択は下書きの位置を正確に保持する")
    @MainActor
    func passageInsertPositionsAreBounded() async throws {
        let store = TestStore(initialState: try makeState(mode: .create)) {
            RouteEditFeature()
        } withDependencies: { $0.installTestSpies() }
        await store.send(.passageAddTapped) {
            $0.destination = .passage
        }
        await store.send(.passageInsertAboveTapped(0)) {
            $0.passageInsertIndex = 0
        }
        await store.send(.passageInsertBelowTapped(100)) {
            $0.passageInsertIndex = 0
        }
        await store.finish()
    }

    @Test("通過町の選択は追加状態を解消し、メモと対象町を保持する")
    @MainActor
    func passageSelectionStoresDistrictAndMemo() async throws {
        let store = TestStore(initialState: try makeState(mode: .create)) {
            RouteEditFeature()
        } withDependencies: { $0.installTestSpies() }
        store.exhaustivity = .off
        await store.send(.passageAddTapped)
        await store.send(.passageSelected(districtId: "town", memo: "turn left"))
        #expect(store.state.passages.count == 1)
        #expect(store.state.passages[0].districtId == "town")
        #expect(store.state.passages[0].memo == "turn left")
        #expect(store.state.passageInsertIndex == nil)
        #expect(store.state.destination == nil)
        await store.finish()
    }

    @Test("保存結果の成功通知は重複した状態変更を起こさない")
    @MainActor
    func modifiedSuccessIsNoop() async throws {
        let store = TestStore(initialState: try makeState(mode: .preview)) {
            RouteEditFeature()
        } withDependencies: { $0.installTestSpies() }
        await store.send(.modified(.success))
        await store.finish()
    }

    private func makeState(
        mode: RouteEditFeature.EditMode,
        points: [Point] = []
    ) throws -> RouteEditFeature.State {
        let route = AppStateFixture.route()
        let appState = Shared<AppState?>(value: AppStateFixture.state(
            routes: [route], points: points, currentRouteId: route.id
        ))
        return try RouteEditFeature.State(mode: mode, route: route, appState: appState)
    }

}
