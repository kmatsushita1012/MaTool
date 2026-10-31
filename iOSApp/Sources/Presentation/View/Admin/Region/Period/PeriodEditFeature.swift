//
//  PeriodEditFeature.swift
//  MaTool
//
//  Created by 松下和也 on 2025/12/07.
//

import ComposableArchitecture
import Shared
import Foundation

@Reducer
struct PeriodEditFeature {
    
    @ObservableState
    struct State: Equatable {
        let mode: Mode
        var period: Period
        var isSaving: Bool = false
        var isDeleting: Bool = false
        var isLoading: Bool { isSaving || isDeleting }
        @Shared fileprivate var appState: AppState?
        @Presents var alert: AlertFeature.State?

        init(mode: Mode, period: Period, appState: Shared<AppState?> = Shared(value: nil)) {
            self.mode = mode
            self.period = period
            self._appState = appState
        }
    }
    
    @CasePathable
    enum Action: Equatable, BindableAction {
        case binding(BindingAction<State>)
        case saveTapped
        case cancelTapped
        case deleteTapped
        case dateChanged(SimpleDate)
        case saveReceived(AppResult<Period>)
        case deleteReceived(AppResult<Period.ID>)
        case catched(AppError)
        case alert(PresentationAction<AlertFeature.Action>)
    }
    
    @Dependency(CreatePeriodUseCaseKey.self) var createPeriodUseCase
    @Dependency(UpdatePeriodUseCaseKey.self) var updatePeriodUseCase
    @Dependency(DeletePeriodUseCaseKey.self) var deletePeriodUseCase
    
    var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce{ state, action in
            switch action {
            case .binding(_):
                return .none
            case .saveTapped:
                state.isSaving = true
                return saveEffect(mode: state.mode, period: state.period, appState: state.$appState)
            case .cancelTapped:
                return .dismiss
            case .deleteTapped:
                guard state.mode == .update else { return .none }
                state.isDeleting = true
                return .task(Action.deleteReceived) { [id = state.period.id, appState = state.$appState] in
                    try await deletePeriodUseCase(id: id, appState: appState)
                    return id
                }
            case .dateChanged(let date):
                if state.mode == .create {
                    let source = state.period
                    state.period = Period(festivalId: source.festivalId, title: source.title, date: date, start: source.start, end: source.end)
                }
                return .none
            case .saveReceived(.failure(let error)),
                .deleteReceived(.failure(let error)):
                state.isSaving = false
                state.isDeleting = false
                state.alert = AlertFeature.error(error.message)
                return .none
            default:
                return .none
            }
        }
        .ifLet(\.$alert, action: \.alert)
    }
    
    private func saveEffect(mode: Mode, period: Period, appState: Shared<AppState?>? = nil) -> Effect<Action> {
        .task(Action.saveReceived) {
            switch mode {
            case .create:
                return try await createPeriodUseCase(period, appState: appState ?? Shared(value: nil))
            case .update:
                return try await updatePeriodUseCase(period, appState: appState ?? Shared(value: nil))
            }
        }
    }
}

extension PeriodEditFeature.State {
    static func update(_ period: Period, appState: Shared<AppState?> = Shared(value: nil)) -> Self {
        .init(
            mode: .update,
            period: period,
            appState: appState
        )
    }
    
    static func create(_ festivalId: String, appState: Shared<AppState?> = Shared(value: nil)) -> Self {
        .init(
            mode: .create,
            period: Period(
                id: UUID().uuidString,
                festivalId: festivalId,
                title: "",
                date: .now,
                start: .init(hour: 9, minute: 0),
                end: .init(hour: 12, minute: 0)
            ),
            appState: appState
        )
    }
    
    var isCreateMode: Bool {
        switch mode {
        case .create:
            return true
        case .update:
            return false
        }
    }
}
