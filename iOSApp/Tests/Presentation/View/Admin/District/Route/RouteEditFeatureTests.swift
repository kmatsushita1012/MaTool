import ComposableArchitecture
import Foundation
import UIKit
import Shared
import Testing
@testable import iOSApp

struct RouteEditFeatureTests {
    @Test("有効な新規・更新経路の保存成功は対応UseCaseへ値を渡し保存完了を受け取る")
    @MainActor
    func successfulRouteSaveInvokesCorrectUseCaseAndCompletes() async throws {
        for mode in [RouteEditFeature.EditMode.create, .update] {
            let first = Point(
                id: "first", routeId: "route",
                coordinate: Coordinate(latitude: 35, longitude: 139),
                time: SimpleTime(hour: 9, minute: 0), anchor: .start, index: 0
            )
            let last = Point(
                id: "last", routeId: "route",
                coordinate: Coordinate(latitude: 36, longitude: 140),
                time: SimpleTime(hour: 10, minute: 0), anchor: .end, index: 1
            )
            let spy = RouteEditSuccessfulSaveSpy()
            let store = TestStore(initialState: try makeState(mode: mode, points: [last, first])) {
                RouteEditFeature()
            } withDependencies: {
                $0.installTestSpies()
                $0[CreateRouteUseCaseKey.self] = spy
                $0[UpdateRouteUseCaseKey.self] = spy
            }
            store.exhaustivity = .off

            await store.send(.saveTapped)
            await store.receive(.saveReceived(.success))
            #expect(await spy.kinds == [mode == .create ? "create" : "update"])
            #expect(await spy.pointIDs == [["first", "last"]])
            await store.finish()
        }
    }

    @Test("経路削除の確認後にUseCaseが成功したら同じRouteIDで完了を受け取る")
    @MainActor
    func successfulRouteDeletionCallsUseCaseExactlyOnce() async throws {
        let spy = RouteEditSuccessfulDeleteSpy()
        let store = TestStore(initialState: try makeState(mode: .update)) {
            RouteEditFeature()
        } withDependencies: {
            $0.installTestSpies()
            $0[DeleteRouteUseCaseKey.self] = spy
        }
        store.exhaustivity = .off

        await store.send(.deleteTapped)
        #expect(store.state.alert?.delete != nil)
        await store.send(.alert(.presented(.delete(.okTapped))))
        #expect(store.state.isDeleting)
        await store.receive(.deleteReceived(.success))
        #expect(await spy.deletedIDs == ["route"])
        await store.finish()
    }

    @Test("画像生成の成功通知は出力画面の一意IDと画像・URLを保持して進行状態を解除する")
    @MainActor
    func successfulPreviewPreparationStoresIdentifiedExportedItem() async throws {
        var initial = try makeState(mode: .update)
        initial.loadingAction = .export
        let item = ExportedItem(
            image: UIImage(),
            url: URL(fileURLWithPath: "/tmp/route-preview.pdf")
        )
        let store = TestStore(initialState: initial) {
            RouteEditFeature()
        } withDependencies: { $0.installTestSpies() }
        store.exhaustivity = .off

        await store.send(.previewPrepared(.success(item)))
        #expect(store.state.destination == .preview(item))
        #expect(store.state.destination?.id == "preview-\(item.id)")
        #expect(!store.state.isLoading)
        await store.finish()
    }

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
        #expect(!state.isConfirmDisabled)
        #expect(!state.isDeleteable)
        #expect(state.title == "新規作成")
        #expect(state.saveButtonTitle == "保存")
        #expect(!state.isLoading)
        #expect(!state.isHistoryLoading)
        #expect(!state.isSourceLoading)
        #expect(!state.isExportLoading)

        state.mode = .update
        #expect(state.title == "編集")
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

    @Test("経路編集のキャンセルは保存・削除の処理状態を開始せず下書きを保持する")
    @MainActor
    func cancellingRouteEditorDoesNotSaveOrDeleteDraft() async throws {
        let initial = try makeState(mode: .update)
        let store = TestStore(initialState: initial) {
            RouteEditFeature()
        } withDependencies: { $0.installTestSpies() }
        let routeId = initial.route.id

        await store.send(.cancelTapped)
        #expect(store.state.route.id == routeId)
        #expect(store.state.loadingAction == nil)
        await store.finish()
    }

    @Test("経路の説明文を編集しても保存アクションが届くまではAPI送信を開始しない")
    @MainActor
    func editingRouteDescriptionChangesOnlyDraft() async throws {
        let initial = try makeState(mode: .update)
        let store = TestStore(initialState: initial) {
            RouteEditFeature()
        } withDependencies: { $0.installTestSpies() }

        await store.send(.binding(.set(\.route.description, "新しい経路説明"))) {
            $0.route.description = "新しい経路説明"
        }
        #expect(store.state.route.description == "新しい経路説明")
        #expect(!store.state.isLoading)
        await store.finish()
    }

    @Test("経路の端点と所属地区を正しい順序で表示し、2地点以上で自動通過町判定を許可する")
    func routePropertiesIdentifyEndpointsAndAutoPassageAvailability() throws {
        let first = Point(
            id: "start", routeId: "route",
            coordinate: .init(latitude: 35.0, longitude: 139.0)
        )
        let last = Point(
            id: "end", routeId: "route",
            coordinate: .init(latitude: 35.1, longitude: 139.1)
        )
        let state = try makeState(mode: .update, points: [first, last])

        #expect(state.start?.id == first.id)
        #expect(state.end?.id == last.id)
        #expect(state.districts.map(\.id).contains("district"))
        #expect(state.districtsById["district"]?.id == "district")
        #expect(!state.isAutoPassageDisabled)
        #expect(RouteEditFeature.Destination.passage.id == "passage")
        #expect(RouteEditFeature.Destination.history([]).id == "history")
    }

    @Test("自動通過町判定は最新の地点と地区領域を使い、以前の手動下書きを再計算結果で置換する")
    @MainActor
    func autoPassageReplacesStalePassagesWithDetectedRoute() async throws {
        let first = Point(
            id: "first", routeId: "route",
            coordinate: .init(latitude: 35.0, longitude: 139.0)
        )
        let last = Point(
            id: "last", routeId: "route",
            coordinate: .init(latitude: 35.1, longitude: 139.1)
        )
        var state = try makeState(mode: .update, points: [first, last])
        state.passages = [
            RoutePassage(id: "stale", routeId: state.route.id, districtId: "deleted-district")
        ]
        let expected = RoutePassageAutoDetector(mode: .includeTouch).makePassages(
            routeId: state.route.id,
            points: state.points,
            districts: state.districts
        )
        let store = TestStore(initialState: state) {
            RouteEditFeature()
        } withDependencies: { $0.installTestSpies() }
        store.exhaustivity = .off

        await store.send(.autoPassageTapped)
        #expect(store.state.passages == expected)
        #expect(!store.state.passages.contains { $0.id == "stale" })
        await store.finish()
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
        let storeInitial = try makeState(mode: .create)
        let store = TestStore(initialState: storeInitial) {
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
        let storeInitial = try makeState(mode: .update)
        let store = TestStore(initialState: storeInitial) {
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
        let newStoreInitial = try makeState(mode: .create)
        let newStore = TestStore(initialState: newStoreInitial) {
            RouteEditFeature()
        } withDependencies: { $0.installTestSpies() }
        newStore.exhaustivity = .off
        await newStore.send(.deleteTapped)
        #expect(newStore.state.alert != nil)
        await newStore.finish()

        let existingStoreInitial = try makeState(mode: .update)

        let existingStore = TestStore(initialState: existingStoreInitial) {
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
        let storeInitial = try makeState(mode: .create)
        let store = TestStore(initialState: storeInitial) {
            RouteEditFeature()
        } withDependencies: { $0.installTestSpies() }
        await store.send(.passageAddTapped) {
            $0.destination = .passage
        }
        await store.send(.passageInsertAboveTapped(0)) {
            $0.passageInsertIndex = 0
        }
        await store.send(.passageInsertBelowTapped(100))
        #expect(store.state.passageInsertIndex == 0)
        await store.finish()
    }

    @Test("通過町の選択は追加状態を解消し、メモと対象町を保持する")
    @MainActor
    func passageSelectionStoresDistrictAndMemo() async throws {
        let storeInitial = try makeState(mode: .create)
        let store = TestStore(initialState: storeInitial) {
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
        let storeInitial = try makeState(mode: .preview)
        let store = TestStore(initialState: storeInitial) {
            RouteEditFeature()
        } withDependencies: { $0.installTestSpies() }
        await store.send(.modified(.success))
        await store.finish()
    }


    @Test("点追加後のUndoとRedoは座標履歴を往復し操作モードを初期化する")
    @MainActor
    func undoRedoRestoresRouteGeometry() async throws {
        let storeInitial = try makeState(mode: .create)
        let store = TestStore(initialState: storeInitial) {
            RouteEditFeature()
        } withDependencies: { $0.installTestSpies() }
        store.exhaustivity = .off
        let coordinate = Coordinate(latitude: 35.1, longitude: 139.1)

        await store.send(.mapLongPressed(coordinate))
        #expect(store.state.points.count == 1)
        #expect(store.state.canUndo)
        await store.send(.undoTapped)
        #expect(store.state.points.isEmpty)
        #expect(store.state.canRedo)
        await store.send(.redoTapped)
        #expect(store.state.points.count == 1)
        #expect(store.state.points.first?.coordinate == coordinate)
        #expect(store.state.operation == .add)
        await store.finish()
    }

    @Test("登録済み経由点のタップで同じIDの編集画面を開く")
    @MainActor
    func tappingPointOpensEditor() async throws {
        let point = Point(
            id: "point", routeId: "route",
            coordinate: Coordinate(latitude: 35, longitude: 139)
        )
        let state = try makeState(mode: .update, points: [point])
        let entry = try #require(state.pointEntries.first)
        let store = TestStore(initialState: state) {
            RouteEditFeature()
        } withDependencies: { $0.installTestSpies() }
        store.exhaustivity = .off

        await store.send(.pointTapped(entry))
        #expect(store.state.point?.point.id == "point")
        #expect(store.state.operation == .add)
        await store.finish()
    }

    @Test("未設定の経路で保存しようとすると不正な点列を拒否しUseCaseを実行しない")
    @MainActor
    func emptyRouteCannotBeSaved() async throws {
        let storeInitial = try makeState(mode: .create)
        let store = TestStore(initialState: storeInitial) {
            RouteEditFeature()
        } withDependencies: { $0.installTestSpies() }
        store.exhaustivity = .off

        await store.send(.saveTapped)
        #expect(store.state.alert?.notice != nil)
        #expect(!store.state.isSaving)
        await store.finish()
    }

    @Test("通過町の選択後に先頭挿入しても既存メモの順序を壊さない")
    @MainActor
    func passageInsertAtBeginningPreservesOrder() async throws {
        let storeInitial = try makeState(mode: .create)
        let store = TestStore(initialState: storeInitial) {
            RouteEditFeature()
        } withDependencies: { $0.installTestSpies() }
        store.exhaustivity = .off

        await store.send(.passageSelected(districtId: "first", memo: "first"))
        await store.send(.passageInsertAboveTapped(0))
        await store.send(.passageSelected(districtId: "new-first", memo: "inserted"))
        #expect(store.state.passages.map(\.memo) == ["inserted", "first"])
        #expect(store.state.passages.map(\.districtId) == ["new-first", "first"])
        #expect(store.state.passageInsertIndex == nil)
        await store.finish()
    }

    @Test("通過町の移動と削除でリスト内の操作対象を正しく反映する")
    @MainActor
    func passageMovementAndDeletionPreserveRemainingPassages() async throws {
        let storeInitial = try makeState(mode: .create)
        let store = TestStore(initialState: storeInitial) {
            RouteEditFeature()
        } withDependencies: { $0.installTestSpies() }
        store.exhaustivity = .off

        await store.send(.passageSelected(districtId: "first", memo: "first"))
        await store.send(.passageSelected(districtId: "second", memo: "second"))
        await store.send(.passageSelected(districtId: "third", memo: "third"))
        await store.send(.passageMoved(from: IndexSet(integer: 0), to: 3))
        #expect(store.state.passages.map(\.memo) == ["second", "third", "first"])
        await store.send(.passageDeleteTapped(1))
        #expect(store.state.passages.map(\.memo) == ["second", "first"])
        await store.finish()
    }

    @Test("保存・削除・経路コピー・画像出力の失敗は操作状態を解除しエラーを伝える")
    @MainActor
    func operationFailuresClearBusyState() async throws {
        let failure = AppError.be(.network("offline"))
        let operations: [(RouteEditFeature.LoadingAction, RouteEditFeature.Action)] = [
            (.save, .saveReceived(.failure(failure))),
            (.delete, .deleteReceived(.failure(failure))),
            (.source, .copyPrepared(.failure(failure))),
            (.export, .previewPrepared(.failure(failure)))
        ]
        for (loading, action) in operations {
            var state = try makeState(mode: .update)
            state.loadingAction = loading
            let store = TestStore(initialState: state) {
                RouteEditFeature()
            } withDependencies: { $0.installTestSpies() }
            store.exhaustivity = .off

            await store.send(action)
            #expect(!store.state.isLoading)
            #expect(store.state.alert?.notice != nil)
            await store.finish()
        }
    }

    @Test("通知アラートの確認で表示を閉じ、画面の編集状態は維持する")
    @MainActor
    func noticeAlertCanBeDismissed() async throws {
        var state = try makeState(mode: .update)
        state.alert = .notice(.notice("Editing is paused"))
        let store = TestStore(initialState: state) {
            RouteEditFeature()
        } withDependencies: { $0.installTestSpies() }
        store.exhaustivity = .off

        await store.send(.alert(.presented(.notice(.okTapped))))
        #expect(store.state.alert == nil)
        #expect(store.state.mode == .update)
        await store.finish()
    }

    @Test("保存エラーの通知結果と編集結果の失敗でそれぞれ理由を保持する")
    @MainActor
    func modifiedFailureKeepsErrorMessage() async throws {
        let storeInitial = try makeState(mode: .preview)
        let store = TestStore(initialState: storeInitial) {
            RouteEditFeature()
        } withDependencies: { $0.installTestSpies() }
        store.exhaustivity = .off

        await store.send(.modified(.failure(.be(.network("offline")))))
        #expect(store.state.alert?.notice != nil)
        await store.finish()
    }

    @Test("地区が更新停止中なら経路編集の開始時に警告し確認モードでは警告しない")
    @MainActor
    func unavailableDistrictShowsNoticeExceptPreview() async throws {
        var state = try makeState(mode: .update)
        state.district.isEditable = false
        let store = TestStore(initialState: state) {
            RouteEditFeature()
        } withDependencies: { $0.installTestSpies() }
        store.exhaustivity = .off

        await store.send(.onAppear)
        #expect(store.state.alert?.notice != nil)
        await store.finish()

        state.mode = .preview
        let preview = TestStore(initialState: state) {
            RouteEditFeature()
        } withDependencies: { $0.installTestSpies() }
        await preview.send(.onAppear)
        #expect(preview.state.alert == nil)
        await preview.finish()
    }

    @Test("編集対象の点はIDで探し不正な時刻を拒否し削除操作だけは検索を許す")
    func findPointForEditingValidatesDraft() throws {
        let point = Point(
            id: "start", routeId: "route",
            coordinate: Coordinate(latitude: 35, longitude: 139),
            time: SimpleTime(hour: 9, minute: 0),
            anchor: .start
        )
        var state = try makeState(mode: .update, points: [point])
        let reducer = RouteEditFeature()
        #expect(reducer.findPointIndex(state)?.index == nil)

        state.point = PointEditFeature.State(
            point, districtId: state.district.id, appState: Shared(value: nil)
        )
        #expect(reducer.findPointIndex(state)?.index == 0)

        var invalidPoint = point
        invalidPoint.time = nil
        state.point = PointEditFeature.State(
            invalidPoint, districtId: state.district.id, appState: Shared(value: nil)
        )
        #expect(reducer.findPointIndex(state)?.index == nil)
        #expect(reducer.findPointIndex(state, ignoreValidation: true)?.index == 0)

        let unrelatedPoint = Point(
            id: "unrelated", routeId: "route",
            coordinate: Coordinate(latitude: 34, longitude: 138)
        )
        state.point = PointEditFeature.State(
            unrelatedPoint, districtId: state.district.id, appState: Shared(value: nil)
        )
        #expect(reducer.findPointIndex(state, ignoreValidation: true)?.index == nil)
    }

    @Test("通過町の挿入位置が負数や件数超過なら末尾へ追加しメモを保持する")
    @MainActor
    func invalidPassageInsertPositionAppendsSafely() async throws {
        var state = try makeState(mode: .create)
        let first = RoutePassage(id: "first", routeId: state.route.id, districtId: "a", memo: "first")
        state.passages = [first]
        state.passageInsertIndex = -1
        let store = TestStore(initialState: state) {
            RouteEditFeature()
        } withDependencies: { $0.installTestSpies() }
        store.exhaustivity = .off

        await store.send(.passageSelected(districtId: "b", memo: "second"))
        #expect(store.state.passages.map(\.memo) == ["first", "second"])
        #expect(store.state.passageInsertIndex == nil)

        await store.send(.passageInsertAboveTapped(50))
        await store.send(.passageSelected(districtId: "c", memo: "third"))
        #expect(store.state.passages.map(\.districtId) == ["a", "b", "c"])
        #expect(store.state.destination == nil)
        await store.finish()
    }


    @Test("有効な経路の保存は新規と更新それぞれのUseCaseへ整列した地点を渡す")
    @MainActor
    func validRouteSaveUsesCorrectUseCase() async throws {
        let error = AppError.be(.network("offline"))
        for mode in [RouteEditFeature.EditMode.create, .update] {
            let first = Point(
                id: "first", routeId: "route",
                coordinate: Coordinate(latitude: 35, longitude: 139),
                time: SimpleTime(hour: 9, minute: 0), anchor: .start, index: 0
            )
            let last = Point(
                id: "last", routeId: "route",
                coordinate: Coordinate(latitude: 36, longitude: 140),
                time: SimpleTime(hour: 10, minute: 0), anchor: .end, index: 1
            )
            var initial = try makeState(mode: mode, points: [last, first])
            initial.passages = [
                RoutePassage(id: "passage", routeId: initial.route.id, districtId: "district", order: 0)
            ]
            let spy = RouteEditSavingSpy(error: error)
            let store = TestStore(initialState: initial) {
                RouteEditFeature()
            } withDependencies: {
                $0.installTestSpies()
                $0[CreateRouteUseCaseKey.self] = spy
                $0[UpdateRouteUseCaseKey.self] = spy
            }
            store.exhaustivity = .off

            await store.send(.saveTapped)
            #expect(store.state.isSaving)
            await store.receive(.saveReceived(.failure(error)))
            #expect(!store.state.isLoading)
            #expect(store.state.alert?.notice != nil)
            #expect(await spy.kinds == [mode == .create ? "create" : "update"])
            #expect(await spy.pointIDs == [["first", "last"]])
            #expect(await spy.passageIDs == [["passage"]])
            await store.finish()
        }
    }

    @Test("履歴コピーの要求で選択地区と祭典IDを渡し戻り値を履歴画面に反映する")
    @MainActor
    func copyTappedFetchesRouteHistory() async throws {
        let entry = RouteEntry(period: AppStateFixture.period(), route: AppStateFixture.route())
        let spy = RouteEditHistoryUseCaseSpy(entries: [entry])
        let initialState = try makeState(mode: .update)
        let store = TestStore(initialState: initialState) {
            RouteEditFeature()
        } withDependencies: {
            $0.installTestSpies()
            $0[FetchRouteHistoryUseCaseKey.self] = spy
        }
        store.exhaustivity = .off

        await store.send(.copyTapped)
        await store.receive(.historyPrepared(.success([entry])))
        #expect(store.state.destination == .history([entry]))
        #expect(await spy.calls == ["district:festival"])
        await store.finish()
    }

    @Test("地点編集の移動要求は同じ点のIDを保ったまま地図の移動操作に切り替える")
    @MainActor
    func pointMoveKeepsOriginalPointIdentity() async throws {
        let point = Point(
            id: "first", routeId: "route",
            coordinate: Coordinate(latitude: 35, longitude: 139),
            time: SimpleTime(hour: 9, minute: 0), anchor: .start
        )
        var initial = try makeState(mode: .update, points: [point])
        initial.point = PointEditFeature.State(
            point, districtId: initial.district.id, appState: Shared(value: nil)
        )
        let store = TestStore(initialState: initial) {
            RouteEditFeature()
        } withDependencies: { $0.installTestSpies() }
        store.exhaustivity = .off

        await store.send(.point(.presented(.moveTapped)))
        #expect(store.state.operation == .move(0))
        #expect(store.state.point == nil)
        #expect(store.state.points.map(\.id) == ["first"])
        await store.finish()
    }

    @Test("時刻を消した不完全な地点でも削除でき、ルート配列から対象だけを除去する")
    @MainActor
    func deleteInvalidPointDoesNotRequireValidation() async throws {
        let original = Point(
            id: "obsolete", routeId: "route",
            coordinate: Coordinate(latitude: 35, longitude: 139),
            time: SimpleTime(hour: 9, minute: 0), anchor: .start
        )
        var invalid = original
        invalid.time = nil
        var initial = try makeState(mode: .update, points: [original])
        initial.point = PointEditFeature.State(
            invalid, districtId: initial.district.id, appState: Shared(value: nil)
        )
        let store = TestStore(initialState: initial) {
            RouteEditFeature()
        } withDependencies: { $0.installTestSpies() }
        store.exhaustivity = .off

        await store.send(.point(.presented(.deleteTapped)))
        #expect(store.state.points.isEmpty)
        #expect(store.state.point == nil)
        await store.finish()
    }


    @Test("地点確定時は編集済み座標を保存し選択画面を閉じる")
    @MainActor
    func pointDoneUpsertsCoordinate() async throws {
        let original = Point(
            id: "first", routeId: "route",
            coordinate: Coordinate(latitude: 35, longitude: 139),
            time: SimpleTime(hour: 9, minute: 0), anchor: .start
        )
        var changed = original
        changed.coordinate = Coordinate(latitude: 35.7, longitude: 139.7)
        var initial = try makeState(mode: .update, points: [original])
        initial.point = PointEditFeature.State(
            changed, districtId: initial.district.id, appState: Shared(value: nil)
        )
        let store = TestStore(initialState: initial) {
            RouteEditFeature()
        } withDependencies: { $0.installTestSpies() }
        store.exhaustivity = .off

        await store.send(.point(.presented(.doneTapped)))
        #expect(store.state.points.first?.coordinate == changed.coordinate)
        #expect(store.state.point == nil)
        await store.finish()
    }


    @Test("削除確認後は対象ルートIDをUseCaseへ渡し失敗時は警告して編集を残す")
    @MainActor
    func confirmedDeletionCallsUseCaseAndShowsFailure() async throws {
        let error = AppError.be(.network("offline"))
        let spy = RouteEditDeleteFailureSpy(error: error)
        let initialState = try makeState(mode: .update)
        let store = TestStore(initialState: initialState) {
            RouteEditFeature()
        } withDependencies: {
            $0.installTestSpies()
            $0[DeleteRouteUseCaseKey.self] = spy
        }
        store.exhaustivity = .off

        await store.send(.deleteTapped)
        #expect(store.state.alert?.delete != nil)
        await store.send(.alert(.presented(.delete(.okTapped))))
        #expect(store.state.isDeleting)
        await store.receive(.deleteReceived(.failure(error)))
        #expect(store.state.alert?.notice != nil)
        #expect(!store.state.isLoading)
        #expect(await spy.deletedIDs == ["route"])
        await store.finish()
    }


    @Test("経路プレビューの修正確定では保存APIを呼ばず元画面へ結果を返す")
    @MainActor
    func previewSaveDoesNotCallCreateOrUpdate() async throws {
        let first = Point(
            id: "first", routeId: "route",
            coordinate: Coordinate(latitude: 35, longitude: 139),
            time: SimpleTime(hour: 9, minute: 0), anchor: .start, index: 0
        )
        let last = Point(
            id: "last", routeId: "route",
            coordinate: Coordinate(latitude: 35.1, longitude: 139.1),
            time: SimpleTime(hour: 10, minute: 0), anchor: .end, index: 1
        )
        let spy = RouteEditSavingSpy(error: .be(.network("unexpected")))
        let initialState = try makeState(mode: .preview, points: [first, last])
        let store = TestStore(initialState: initialState) {
            RouteEditFeature()
        } withDependencies: {
            $0.installTestSpies()
            $0[CreateRouteUseCaseKey.self] = spy
            $0[UpdateRouteUseCaseKey.self] = spy
        }
        store.exhaustivity = .off

        await store.send(.saveTapped)
        await store.receive(.modified(.success))
        #expect(!store.state.isSaving)
        #expect(await spy.kinds.isEmpty)
        await store.finish()
    }


    @Test("地区領域の表示はプレビューモードかつポリゴンがある場合のみ切替可能")
    @MainActor
    func districtAreaOverlayToggleRespectsPreviewAvailability() async throws {
        var initial = try makeState(mode: .preview)
        initial.districtAreaOverlays = [
            DistrictAreaOverlay(
                districtId: "district", districtName: "町",
                area: [
                    Coordinate(latitude: 35, longitude: 139),
                    Coordinate(latitude: 35.1, longitude: 139),
                    Coordinate(latitude: 35, longitude: 139.1)
                ],
                center: Coordinate(latitude: 35.03, longitude: 139.03),
                colorIndex: 0
            )
        ]
        let store = TestStore(initialState: initial) {
            RouteEditFeature()
        } withDependencies: { $0.installTestSpies() }

        await store.send(.districtAreaOverlayTapped) {
            $0.isDistrictAreaOverlayVisible = true
        }
        await store.send(.districtAreaOverlayTapped) {
            $0.isDistrictAreaOverlayVisible = false
        }
        #expect(store.state.canShowDistrictAreaOverlay)
        await store.finish()

        initial.mode = .update
        let updateStore = TestStore(initialState: initial) {
            RouteEditFeature()
        } withDependencies: { $0.installTestSpies() }
        await updateStore.send(.districtAreaOverlayTapped)
        #expect(!updateStore.state.isDistrictAreaOverlayVisible)
        await updateStore.finish()
    }


    @Test("出力時にセッションが解放されていた場合は全体・部分とも画像化せず理由を通知する")
    @MainActor
    func exportsWithoutSessionFailBeforeSnapshot() async throws {
        let route = AppStateFixture.route()
        let error = AppError.export(.notFound("必要な情報の取得に失敗しました。"))
        for partial in [false, true] {
            let shared = Shared<AppState?>(value: AppStateFixture.state(
                routes: [route], currentRouteId: route.id
            ))
            var initial = try RouteEditFeature.State(
                mode: .update, route: route, appState: shared
            )
            initial.size = CGSize(width: 320, height: 240)
            shared.withLock { $0 = nil }
            let store = TestStore(initialState: initial) {
                RouteEditFeature()
            } withDependencies: { $0.installTestSpies() }
            store.exhaustivity = .off

            await store.send(partial ? .partialTapped : .wholeTapped)
            #expect(store.state.loadingAction == .export)
            await store.receive(.previewPrepared(.failure(error)))
            #expect(!store.state.isLoading)
            #expect(store.state.alert?.notice != nil)
            await store.finish()
        }
    }


    @Test("経由点の前後挿入は選択した地点の位置を維持して挿入インデックスを決める")
    @MainActor
    func pointInsertActionsChooseCorrectInsertionIndex() async throws {
        let first = Point(
            id: "first", routeId: "route",
            coordinate: Coordinate(latitude: 35, longitude: 139),
            time: SimpleTime(hour: 9, minute: 0), anchor: .start, index: 0
        )
        let second = Point(
            id: "second", routeId: "route",
            coordinate: Coordinate(latitude: 35.1, longitude: 139.1),
            time: SimpleTime(hour: 10, minute: 0), anchor: .end, index: 1
        )
        for (action, expected) in [
            (PointEditFeature.Action.insertBeforeTapped, RouteEditFeature.Operation.insert(0)),
            (PointEditFeature.Action.insertAfterTapped, RouteEditFeature.Operation.insert(1))
        ] {
            var initial = try makeState(mode: .update, points: [first, second])
            initial.point = PointEditFeature.State(
                first, districtId: initial.district.id, appState: Shared(value: nil)
            )
            let store = TestStore(initialState: initial) {
                RouteEditFeature()
            } withDependencies: { $0.installTestSpies() }
            store.exhaustivity = .off

            await store.send(.point(.presented(action)))
            #expect(store.state.operation == expected)
            #expect(store.state.point == nil)
            #expect(store.state.points.map(\.id) == ["first", "second"])
            await store.finish()
        }
    }

    @Test("最後の地点の後ろには重複した途中挿入状態を作らず追加モードを維持する")
    @MainActor
    func insertionAfterLastPointFallsBackToAppend() async throws {
        let last = Point(
            id: "last", routeId: "route",
            coordinate: Coordinate(latitude: 35.1, longitude: 139.1),
            time: SimpleTime(hour: 10, minute: 0), anchor: .end
        )
        var initial = try makeState(mode: .update, points: [last])
        initial.point = PointEditFeature.State(
            last, districtId: initial.district.id, appState: Shared(value: nil)
        )
        let store = TestStore(initialState: initial) {
            RouteEditFeature()
        } withDependencies: { $0.installTestSpies() }
        store.exhaustivity = .off

        await store.send(.point(.presented(.insertAfterTapped)))
        #expect(store.state.operation == .add)
        #expect(store.state.point == nil)
        #expect(store.state.points.map(\.id) == ["last"])
        await store.finish()
    }

    @Test("過去の経路を選んだ時にRouteIDをUseCaseへ渡しコピーとして取り込む")
    @MainActor
    func sourceSelectedLoadsRoutePackBeforeCopying() async throws {
        let source = AppStateFixture.route(id: "source-route", description: "history")
        let pack = RoutePack(route: source, points: [], passages: [])
        let spy = RouteEditFetchPackSpy(pack: pack)
        let initialState = try makeState(mode: .update)
        let store = TestStore(initialState: initialState) {
            RouteEditFeature()
        } withDependencies: {
            $0.installTestSpies()
            $0[FetchRoutePackUseCaseKey.self] = spy
        }
        store.exhaustivity = .off

        await store.send(.sourceSelected(.init(period: AppStateFixture.period(), route: source)))
        await store.receive(.copyPrepared(.success(pack)))
        #expect(await spy.ids == [source.id])
        #expect(!store.state.isSourceLoading)
        #expect(store.state.mode == .create)
        #expect(store.state.route.id != source.id)
        #expect(store.state.route.districtId == "district")
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


private actor RouteEditSuccessfulSaveSpy: CreateRouteUseCaseProtocol, UpdateRouteUseCaseProtocol {
    private(set) var kinds: [String] = []
    private(set) var pointIDs: [[String]] = []

    func callAsFunction(
        districtId: District.ID, route: Route, points: [Point],
        passages: [RoutePassage], appState: Shared<AppState?>
    ) async throws -> RoutePack {
        kinds.append("create")
        pointIDs.append(points.map(\.id))
        return RoutePack(route: route, points: points, passages: passages)
    }

    func callAsFunction(
        _ route: Route, points: [Point], passages: [RoutePassage],
        appState: Shared<AppState?>
    ) async throws -> RoutePack {
        kinds.append("update")
        pointIDs.append(points.map(\.id))
        return RoutePack(route: route, points: points, passages: passages)
    }
}

private actor RouteEditSavingSpy: CreateRouteUseCaseProtocol, UpdateRouteUseCaseProtocol {
    let error: AppError
    private(set) var kinds: [String] = []
    private(set) var pointIDs: [[String]] = []
    private(set) var passageIDs: [[String]] = []

    init(error: AppError) { self.error = error }

    func callAsFunction(
        districtId: District.ID, route: Route, points: [Point],
        passages: [RoutePassage], appState: Shared<AppState?>
    ) async throws -> RoutePack {
        kinds.append("create")
        pointIDs.append(points.map(\.id))
        passageIDs.append(passages.map(\.id))
        throw error
    }

    func callAsFunction(
        _ route: Route, points: [Point], passages: [RoutePassage],
        appState: Shared<AppState?>
    ) async throws -> RoutePack {
        kinds.append("update")
        pointIDs.append(points.map(\.id))
        passageIDs.append(passages.map(\.id))
        throw error
    }
}

private actor RouteEditHistoryUseCaseSpy: FetchRouteHistoryUseCaseProtocol {
    let entries: [RouteEntry]
    private(set) var calls: [String] = []

    init(entries: [RouteEntry]) { self.entries = entries }

    func callAsFunction(
        districtId: District.ID, festivalId: Festival.ID
    ) async throws -> [RouteEntry] {
        calls.append("\(districtId):\(festivalId)")
        return entries
    }
}


private actor RouteEditSuccessfulDeleteSpy: DeleteRouteUseCaseProtocol {
    private(set) var deletedIDs: [Route.ID] = []

    func callAsFunction(routeId: Route.ID, appState: Shared<AppState?>) async throws {
        deletedIDs.append(routeId)
    }
}

private actor RouteEditDeleteFailureSpy: DeleteRouteUseCaseProtocol {
    let error: AppError
    private(set) var deletedIDs: [Route.ID] = []

    init(error: AppError) { self.error = error }

    func callAsFunction(routeId: Route.ID, appState: Shared<AppState?>) async throws {
        deletedIDs.append(routeId)
        throw error
    }
}

private actor RouteEditFetchPackSpy: FetchRoutePackUseCaseProtocol {
    let pack: RoutePack
    private(set) var ids: [Route.ID] = []

    init(pack: RoutePack) {
        self.pack = pack
    }

    func callAsFunction(routeId: Route.ID) async throws -> RoutePack {
        ids.append(routeId)
        return pack
    }
}
