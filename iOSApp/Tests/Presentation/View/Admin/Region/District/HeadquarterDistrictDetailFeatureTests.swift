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

    private func makeState() -> HeadquarterDistrictDetailFeature.State {
        HeadquarterDistrictDetailFeature.State(
            AppStateFixture.district(),
            appState: Shared<AppState?>(value: AppStateFixture.state())
        )
    }
}
