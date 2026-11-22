import ComposableArchitecture
import Foundation
import Shared

@Reducer
struct EditionEditFeature {
    @ObservableState
    struct State: Equatable {
        let festivalID: Festival.ID
        let edition: Edition
        var periods: [Period]
        var serverPeriods: [Period]
        var activeEditionID: Edition.ID?
        var isLoading = false
        var isSaving = false
        var isActivating = false
        var hasLoaded = false
        var hasLoadError = false
        @Shared fileprivate var appState: AppState?
        @Presents var periodEditor: PeriodDraftEditFeature.State?
        @Presents var alert: AlertFeature.State?

        var isActive: Bool { activeEditionID == edition.id }
        var isDirty: Bool { periods != serverPeriods }
        var isBusy: Bool { isLoading || isSaving || isActivating }

        init(
            festivalID: Festival.ID,
            edition: Edition,
            activeEditionID: Edition.ID?,
            appState: Shared<AppState?> = Shared(value: nil)
        ) {
            self.festivalID = festivalID
            self.edition = edition
            self.periods = []
            self.serverPeriods = []
            self.activeEditionID = activeEditionID
            self._appState = appState
        }

        init(
            festivalID: Festival.ID,
            pack: EditionPack,
            activeEditionID: Edition.ID?,
            appState: Shared<AppState?> = Shared(value: nil)
        ) {
            self.festivalID = festivalID
            self.edition = pack.edition
            self.periods = pack.periods.sorted()
            self.serverPeriods = pack.periods.sorted()
            self.activeEditionID = activeEditionID
            self._appState = appState
            self.hasLoaded = true
        }
    }

    @CasePathable
    enum Action: Equatable, BindableAction {
        case binding(BindingAction<State>)
        case onAppear
        case addPeriodTapped
        case periodTapped(Period)
        case saveTapped
        case saveReceived(AppResult<EditionPack>)
        case activateTapped
        case activationReceived(AppResult<EditionActivationResult>)
        case packReceived(AppResult<EditionPack>)
        case serverSnapshotReceived(AppResult<EditionPack>)
        case periodEditor(PresentationAction<PeriodDraftEditFeature.Action>)
        case alert(PresentationAction<AlertFeature.Action>)
    }

    @Dependency(EditionDataFetcherKey.self) private var editionDataFetcher
    @Dependency(SaveEditionPackUseCaseKey.self) private var saveEditionPackUseCase
    @Dependency(ActivateEditionUseCaseKey.self) private var activateEditionUseCase

    var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .binding:
                return .none
            case .onAppear:
                guard !state.hasLoaded else { return .none }
                state.isLoading = true
                state.hasLoadError = false
                return fetchPackEffect(state, action: Action.packReceived)
            case .addPeriodTapped:
                guard !state.isBusy, state.hasLoaded else { return .none }
                state.periodEditor = makeNewPeriod(for: state.edition)
                return .none
            case .periodTapped(let period):
                guard !state.isBusy else { return .none }
                state.periodEditor = .update(period, festivalID: state.festivalID)
                return .none
            case .saveTapped:
                guard !state.isBusy, state.hasLoaded else { return .none }
                state.isSaving = true
                let pack = EditionPack(edition: state.edition, periods: state.periods.sorted())
                let appState = state.$appState
                return .task(Action.saveReceived) {
                    try await saveEditionPackUseCase(pack, appState: appState)
                }
            case .saveReceived(.success(let pack)):
                state.isSaving = false
                state.hasLoaded = true
                state.periods = pack.periods.sorted()
                state.serverPeriods = pack.periods.sorted()
                state.alert = AlertFeature.success("年度と日程を保存しました。")
                return .none
            case .saveReceived(.failure(let error)):
                state.isSaving = false
                state.alert = AlertFeature.error("保存に失敗しました。編集内容は保持しています。\n\(error.message)")
                return fetchPackEffect(state, action: Action.serverSnapshotReceived)
            case .activateTapped:
                guard !state.isBusy, state.hasLoaded, !state.isActive, !state.isDirty else { return .none }
                state.isActivating = true
                let appState = state.$appState
                return .task(Action.activationReceived) { [festivalID = state.festivalID, editionID = state.edition.id] in
                    try await activateEditionUseCase(
                        festivalID: festivalID,
                        editionID: editionID,
                        appState: appState
                    )
                }
            case .activationReceived(.success(let result)):
                state.isActivating = false
                state.activeEditionID = result.activeEdition.editionId
                if let error = result.appStateReloadError {
                    state.alert = AlertFeature.error("年度は切り替わりましたが、起動データを再取得できませんでした。\n\(error.message)")
                } else {
                    state.alert = AlertFeature.success("有効な年度に合わせて起動データを更新しました。")
                }
                return .none
            case .activationReceived(.failure(let error)):
                state.isActivating = false
                state.alert = AlertFeature.error("有効化に失敗しました。\n\(error.message)")
                return .none
            case .packReceived(.success(let pack)):
                state.isLoading = false
                state.hasLoaded = true
                state.hasLoadError = false
                state.periods = pack.periods.sorted()
                state.serverPeriods = pack.periods.sorted()
                return .none
            case .packReceived(.failure(let error)):
                state.isLoading = false
                state.hasLoadError = true
                state.alert = AlertFeature.error("年度情報を取得できませんでした。\n\(error.message)")
                return .none
            case .serverSnapshotReceived(.success(let pack)):
                state.serverPeriods = pack.periods.sorted()
                return .none
            case .serverSnapshotReceived(.failure):
                return .none
            case .periodEditor(.presented(.saveTapped)):
                guard let period = state.periodEditor?.period else { return .none }
                upsert(period, in: &state.periods)
                state.periodEditor = nil
                return .none
            case .periodEditor(.presented(.deleteTapped)):
                guard let id = state.periodEditor?.period.id else { return .none }
                state.periods.removeAll { $0.id == id }
                state.periodEditor = nil
                return .none
            case .alert(.presented):
                state.alert = nil
                return .none
            default:
                return .none
            }
        }
        .ifLet(\.$periodEditor, action: \.periodEditor) {
            PeriodDraftEditFeature()
        }
        .ifLet(\.$alert, action: \.alert)
    }

    private func fetchPackEffect(
        _ state: State,
        action: @escaping (AppResult<EditionPack>) -> Action
    ) -> Effect<Action> {
        .task(action) { [festivalID = state.festivalID, year = state.edition.year] in
            try await editionDataFetcher.fetch(festivalID: festivalID, year: year)
        }
    }

    private func makeNewPeriod(for edition: Edition) -> PeriodDraftEditFeature.State {
        .create(Period(
            id: UUID().uuidString,
            editionId: edition.id,
            festivalId: edition.festivalId,
            title: "",
            date: .now,
            start: SimpleTime(hour: 9, minute: 0),
            end: SimpleTime(hour: 12, minute: 0)
        ), festivalID: edition.festivalId)
    }

    private func upsert(_ period: Period, in periods: inout [Period]) {
        periods.removeAll { $0.id == period.id }
        periods.append(period)
        periods.sort()
    }
}
