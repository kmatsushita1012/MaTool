import ComposableArchitecture
import Foundation
import Shared
import Testing
@testable import iOSApp

struct HeadquarterDistrictDetailFeatureTests {
    @Test("表示順は0から始まる永続値を1から始まる入力値へ変換する")
    func displayedOrderClampsInvalidInput() {
        var district = AppStateFixture.district()
        district.order = 4
        var state = HeadquarterDistrictDetailFeature.State(
            district, appState: Shared<AppState?>(value: AppStateFixture.state())
        )
        #expect(state.displayedOrder == 5)
        state.displayedOrder = 1
        #expect(state.district.order == 0)
        state.displayedOrder = -20
        #expect(state.district.order == 0)
        state.displayedOrder = 15
        #expect(state.district.order == 14)
    }

    @Test("PDFの種類に応じてローディングフラグを個別に切り替える")
    func exportIndicatorsMatchExportKind() {
        var state = makeState()
        #expect(!state.isExportLoading)
        state.activeExportKind = .submission
        #expect(state.isExportLoading)
        #expect(state.isSubmissionExportLoading)
        #expect(!state.isTableExportLoading)
        state.activeExportKind = .table
        #expect(state.isExportLoading)
        #expect(state.isTableExportLoading)
        #expect(!state.isSubmissionExportLoading)
        state.activeExportKind = nil
        #expect(!state.isExportLoading)
    }

    @Test("編集開始はAppStateから地区の最新値を読み込み編集可能にする")
    @MainActor
    func editTappedRefreshesDistrict() async {
        var oldDistrict = AppStateFixture.district()
        oldDistrict.name = "old"
        let store = TestStore(initialState: HeadquarterDistrictDetailFeature.State(
            oldDistrict, appState: Shared<AppState?>(value: AppStateFixture.state())
        )) {
            HeadquarterDistrictDetailFeature()
        } withDependencies: { $0.installTestSpies() }
        store.exhaustivity = .off
        await store.send(.editTapped)
        #expect(store.state.isEditable)
        #expect(store.state.district.name != "old")
        await store.finish()
    }

    @Test("再発行ボタンは現在の地区IDを渡して専用画面に遷移する")
    @MainActor
    func reissueTappedKeepsDistrictIdentity() async {
        let store = TestStore(initialState: makeState()) {
            HeadquarterDistrictDetailFeature()
        } withDependencies: { $0.installTestSpies() }
        store.exhaustivity = .off
        await store.send(.reissueTapped)
        #expect(store.state.destination?.reissue?.districtId == AppStateFixture.district().id)
        await store.finish()
    }

    @Test("空の編集ドラフトを破棄しても状態は変わらない")
    @MainActor
    func resetEmptyDraftsIsNoop() async {
        let store = TestStore(initialState: makeState()) {
            HeadquarterDistrictDetailFeature()
        } withDependencies: { $0.installTestSpies() }
        await store.send(.resetDraftsTapped)
        #expect(store.state.routeDrafts.isEmpty)
        await store.finish()
    }

    @Test("地区更新成功後は変更結果を取り込み編集モードと保存状態を終了する")
    @MainActor
    func successfulUpdateStoresServerDistrict() async {
        var state = makeState()
        state.isEditable = true
        state.isLoading = true
        state.isSaving = true
        let store = TestStore(initialState: state) {
            HeadquarterDistrictDetailFeature()
        } withDependencies: { $0.installTestSpies() }
        var updated = AppStateFixture.district()
        updated.name = "updated by server"

        await store.send(.updateReceived(.success(updated))) {
            $0.isLoading = false
            $0.isSaving = false
            $0.district = updated
            $0.isEditable = false
        }
        #expect(store.state.district.name == "updated by server")
        await store.finish()
    }

    @Test("経路が見つからない場合はローディングのみ解除して遷移しない")
    @MainActor
    func missingRouteResultDoesNotNavigate() async {
        var state = makeState()
        state.isLoading = true
        let store = TestStore(initialState: state) {
            HeadquarterDistrictDetailFeature()
        } withDependencies: { $0.installTestSpies() }
        await store.send(.routeReceived(.success(nil))) {
            $0.isLoading = false
        }
        #expect(store.state.destination == nil)
        await store.finish()
    }

    @Test("PDF生成完了時は共有URLを格納し出力中フラグを消す")
    @MainActor
    func successfulExportProducesShareableURL() async {
        var state = makeState()
        state.activeExportKind = .table
        let store = TestStore(initialState: state) {
            HeadquarterDistrictDetailFeature()
        } withDependencies: { $0.installTestSpies() }
        let url = URL(fileURLWithPath: "/tmp/export.pdf")
        await store.send(.batchExportReceived(.success(url))) {
            $0.activeExportKind = nil
            $0.url = url
        }
        #expect(!store.state.isExportLoading)
        await store.finish()
    }

    @Test("保存・経路読込・PDF出力の失敗は同じ方法で状態を解除し理由を表示する")
    @MainActor
    func failuresClearAllBusyFlags() async {
        for kind in 0..<3 {
            let error = AppError.be(.network("offline"))
            var state = makeState()
            state.isLoading = true
            state.isSaving = true
            state.activeExportKind = .submission
            let store = TestStore(initialState: state) {
                HeadquarterDistrictDetailFeature()
            } withDependencies: { $0.installTestSpies() }
            let action: HeadquarterDistrictDetailFeature.Action
            switch kind {
            case 0: action = .updateReceived(.failure(error))
            case 1: action = .routeReceived(.failure(error))
            default: action = .batchExportReceived(.failure(error))
            }
            await store.send(action) {
                $0.isLoading = false
                $0.isSaving = false
                $0.activeExportKind = nil
                $0.alert = AlertFeature.error(error.message)
            }
            #expect(!store.state.isLoading)
            #expect(!store.state.isExportLoading)
            await store.finish()
        }
    }

    @Test("編集済み地区の保存はUseCaseを1回だけ呼び、成功応答で編集を終了する")
    @MainActor
    func saveEditedDistrictInvokesUseCase() async {
        let updated = AppStateFixture.district(name: "saved")
        let spy = DetailSaveDistrictSpy(updated: updated)
        var initial = makeState()
        initial.isEditable = true
        initial.district.name = "draft"
        let store = TestStore(initialState: initial) {
            HeadquarterDistrictDetailFeature()
        } withDependencies: {
            $0.installTestSpies()
            $0[SaveDistrictUseCaseKey.self] = spy
        }

        await store.send(.editTapped) {
            $0.isLoading = true
            $0.isSaving = true
        }
        await store.receive(.updateReceived(.success(updated))) {
            $0.isLoading = false
            $0.isSaving = false
            $0.district = updated
            $0.isEditable = false
        }
        #expect(await spy.savedNames == ["draft"])
        await store.finish()
    }

    @Test("既存の経路を選択するとRouteIDをUseCaseに渡し編集用ドラフトを開く")
    @MainActor
    func selectedRouteLoadsPackAndOpensPreview() async {
        let route = AppStateFixture.route()
        let pack = RoutePack(route: route, points: [], passages: [])
        let spy = DetailRouteLoadSpy(pack: pack)
        let store = TestStore(initialState: makeState()) {
            HeadquarterDistrictDetailFeature()
        } withDependencies: {
            $0.installTestSpies()
            $0[LoadRouteStateUseCaseKey.self] = spy
        }
        store.exhaustivity = .off

        await store.send(.routeSelected(.init(period: AppStateFixture.period(), route: route)))
        await store.receive(.routeReceived(.success(pack)))
        #expect(store.state.destination?.route?.route.id == route.id)
        #expect(store.state.destination?.route?.mode == .preview)
        #expect(await spy.ids == [route.id])
        await store.finish()
    }

    @Test("経路未作成の期間を選択してもUseCaseを呼び出さない")
    @MainActor
    func emptyRouteSelectionIsNoop() async {
        let spy = DetailRouteLoadSpy(pack: nil)
        let store = TestStore(initialState: makeState()) {
            HeadquarterDistrictDetailFeature()
        } withDependencies: {
            $0.installTestSpies()
            $0[LoadRouteStateUseCaseKey.self] = spy
        }
        await store.send(.routeSelected(.init(period: AppStateFixture.period(), route: nil)))
        #expect(store.state.destination == nil)
        #expect(await spy.ids.isEmpty)
        await store.finish()
    }

    @Test("ローカルに修正済み経路があれば再読込せずそのドラフトを表示する")
    @MainActor
    func cachedRouteDraftOpensWithoutNetwork() async {
        let route = AppStateFixture.route()
        let spy = DetailRouteLoadSpy(pack: nil)
        var state = makeState()
        state.routeDrafts[route.id] = RouteDraft(route: route, points: [], passages: [])
        let store = TestStore(initialState: state) {
            HeadquarterDistrictDetailFeature()
        } withDependencies: {
            $0.installTestSpies()
            $0[LoadRouteStateUseCaseKey.self] = spy
        }
        store.exhaustivity = .off

        await store.send(.routeSelected(.init(period: AppStateFixture.period(), route: route)))
        #expect(store.state.destination?.route?.mode == .preview)
        #expect(await spy.ids.isEmpty)
        await store.finish()
    }

    @Test("経路ドラフトの破棄ボタンで未保存の差分だけを初期化する")
    @MainActor
    func resetDraftsRemovesOnlyLocalRouteChanges() async {
        let route = AppStateFixture.route()
        var initial = makeState()
        initial.routeDrafts[route.id] = RouteDraft(route: route, points: [], passages: [])
        let store = TestStore(initialState: initial) {
            HeadquarterDistrictDetailFeature()
        } withDependencies: { $0.installTestSpies() }
        await store.send(.resetDraftsTapped) {
            $0.routeDrafts = [:]
        }
        #expect(store.state.district.id == "district")
        await store.finish()
    }

    private func makeState() -> HeadquarterDistrictDetailFeature.State {
        HeadquarterDistrictDetailFeature.State(
            AppStateFixture.district(),
            appState: Shared<AppState?>(value: AppStateFixture.state())
        )
    }
}

private actor DetailSaveDistrictSpy: SaveDistrictUseCaseProtocol {
    private(set) var savedNames: [String] = []
    let updated: District

    init(updated: District) { self.updated = updated }

    func callAsFunction(district: District, appState: Shared<AppState?>) async throws -> District {
        savedNames.append(district.name)
        return updated
    }
}

private actor DetailRouteLoadSpy: LoadRouteStateUseCaseProtocol {
    private(set) var ids: [Route.ID] = []
    let pack: RoutePack?

    init(pack: RoutePack?) { self.pack = pack }

    func callAsFunction(routeId: Route.ID, appState: Shared<AppState?>) async throws -> RoutePack? {
        ids.append(routeId)
        return pack
    }
}
