import ComposableArchitecture
import Dependencies
import Shared
import Testing
@testable import iOSApp

struct PeriodEditFeatureTests {
    @Test("作成画面は祭典ID・標準開始時刻・空タイトルを初期化する")
    func initialCreateState() {
        let state = PeriodEditFeature.State.create("festival")

        #expect(state.isCreateMode)
        #expect(state.mode == .create)
        #expect(state.period.festivalId == "festival")
        #expect(state.period.title.isEmpty)
        #expect(state.period.start == SimpleTime(hour: 9, minute: 0))
        #expect(state.period.end == SimpleTime(hour: 12, minute: 0))
        #expect(!state.isLoading)
    }

    @Test("編集画面は元の期間を維持して削除を許可する")
    func initialUpdateState() {
        let period = AppStateFixture.period()
        let state = PeriodEditFeature.State.update(period)

        #expect(!state.isCreateMode)
        #expect(state.mode == .update)
        #expect(state.period == period)
    }

    @Test("作成時の日付変更はタイトル・開始終了時刻を保って新しい期間を生成する")
    @MainActor
    func creationDateChangeKeepsOtherFields() async {
        let original = AppStateFixture.period(id: "temporary")
        let store = TestStore(initialState: PeriodEditFeature.State(
            mode: .create, period: original
        )) {
            PeriodEditFeature()
        } withDependencies: { $0.installTestSpies() }
        store.exhaustivity = .off
        let changedDate = SimpleDate(year: 2027, month: 10, day: 1)

        await store.send(.dateChanged(changedDate))

        #expect(store.state.period.date == changedDate)
        #expect(store.state.period.festivalId == original.festivalId)
        #expect(store.state.period.title == original.title)
        #expect(store.state.period.start == original.start)
        #expect(store.state.period.end == original.end)
        #expect(store.state.period.id != original.id)
        await store.finish()
    }

    @Test("編集モードの日付変更アクションは既存期間のIDと日付を維持する")
    @MainActor
    func updateDateActionIsIgnored() async {
        let period = AppStateFixture.period()
        let store = TestStore(initialState: .update(period)) {
            PeriodEditFeature()
        } withDependencies: { $0.installTestSpies() }

        await store.send(.dateChanged(SimpleDate(year: 2027, month: 1, day: 1)))
        #expect(store.state.period == period)
        await store.finish()
    }

    @Test("作成画面の削除アクションではAPIを呼ばず状態を変えない")
    @MainActor
    func deletionIsNotAvailableDuringCreation() async {
        let period = AppStateFixture.period()
        let store = TestStore(initialState: .init(mode: .create, period: period)) {
            PeriodEditFeature()
        } withDependencies: { $0.installTestSpies() }

        await store.send(.deleteTapped)
        #expect(!store.state.isDeleting)
        await store.finish()
    }

    @Test("作成ボタンは保存中へ遷移して作成UseCaseの結果を返す")
    @MainActor
    func savingNewPeriodUsesCreateCase() async {
        let period = AppStateFixture.period()
        let store = TestStore(initialState: .init(mode: .create, period: period)) {
            PeriodEditFeature()
        } withDependencies: {
            $0.installTestSpies()
            $0[CreatePeriodUseCaseKey.self] = StubCreatePeriodUseCase(response: period)
        }

        await store.send(.saveTapped) {
            $0.isSaving = true
        }
        await store.receive(.saveReceived(.success(period)))
        await store.finish()
    }

    @Test("更新ボタンは既存期間を更新UseCaseへ渡して結果を返す")
    @MainActor
    func savingExistingPeriodUsesUpdateCase() async {
        let period = AppStateFixture.period()
        let store = TestStore(initialState: .update(period)) {
            PeriodEditFeature()
        } withDependencies: {
            $0.installTestSpies()
            $0[UpdatePeriodUseCaseKey.self] = StubUpdatePeriodUseCase(response: period)
        }

        await store.send(.saveTapped) { $0.isSaving = true }
        await store.receive(.saveReceived(.success(period)))
        await store.finish()
    }

    @Test("削除ボタンは更新モードだけで動作し削除されたIDを返す")
    @MainActor
    func deletingExistingPeriodUsesDeleteCase() async {
        let period = AppStateFixture.period()
        let store = TestStore(initialState: .update(period)) {
            PeriodEditFeature()
        } withDependencies: {
            $0.installTestSpies()
            $0[DeletePeriodUseCaseKey.self] = StubDeletePeriodUseCase()
        }

        await store.send(.deleteTapped) { $0.isDeleting = true }
        await store.receive(.deleteReceived(.success("period")))
        await store.finish()
    }

    @Test("保存失敗時は保存フラグを解除し具体的なエラーを表示する")
    @MainActor
    func saveFailureStopsLoading() async {
        let period = AppStateFixture.period()
        var state = PeriodEditFeature.State.update(period)
        state.isSaving = true
        let store = TestStore(initialState: state) {
            PeriodEditFeature()
        } withDependencies: { $0.installTestSpies() }
        let error = AppError.be(.network("offline"))

        await store.send(.saveReceived(.failure(error))) {
            $0.isSaving = false
            $0.isDeleting = false
            $0.alert = AlertFeature.error(error.message)
        }
        #expect(!store.state.isLoading)
        await store.finish()
    }

    @Test("削除失敗時は削除フラグを解除してアラートを表示する")
    @MainActor
    func deleteFailureStopsLoading() async {
        let period = AppStateFixture.period()
        var state = PeriodEditFeature.State.update(period)
        state.isDeleting = true
        let store = TestStore(initialState: state) {
            PeriodEditFeature()
        } withDependencies: { $0.installTestSpies() }
        let error = AppError.be(.forbidden("not allowed"))

        await store.send(.deleteReceived(.failure(error))) {
            $0.isSaving = false
            $0.isDeleting = false
            $0.alert = AlertFeature.error(error.message)
        }
        await store.finish()
    }

    @Test("Bindingは各モデルの値をStoreに保持する")
    @MainActor
    func bindingMaintainsEditedTitle() async {
        let period = AppStateFixture.period()
        let store = TestStore(initialState: .update(period)) {
            PeriodEditFeature()
        } withDependencies: { $0.installTestSpies() }

        await store.send(.binding(.set(\.period.title, "Updated title"))) {
            $0.period.title = "Updated title"
        }
        #expect(store.state.period.title == "Updated title")
        await store.finish()
    }
}

private struct StubCreatePeriodUseCase: CreatePeriodUseCaseProtocol {
    let response: Period

    func callAsFunction(_ period: Period, appState: Shared<AppState?>) async throws -> Period {
        response
    }
}

private struct StubUpdatePeriodUseCase: UpdatePeriodUseCaseProtocol {
    let response: Period

    func callAsFunction(_ period: Period, appState: Shared<AppState?>) async throws -> Period {
        response
    }
}

private struct StubDeletePeriodUseCase: DeletePeriodUseCaseProtocol {
    func callAsFunction(id: Period.ID, appState: Shared<AppState?>) async throws {}
}
