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
        var isLoading: Bool = false
        @Presents var alert: Alert.State?
    }
    
    @CasePathable
    enum Action: Equatable, BindableAction {
        case binding(BindingAction<State>)
        case doneTapped
        case deleteTapped
        case dateChanged(SimpleDate)
        case saveReceived(VoidTaskResult)
        case deleteReceived(VoidTaskResult)
        case catched(APIError)
        case alert(PresentationAction<Alert.Action>)
    }
    
    @Dependency(PeriodDataFetcherKey.self) var dataFetcher
    
    var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce{ state, action in
            switch action {
            case .binding(_):
                return .none
            case .doneTapped:
                state.isLoading = true
                return saveEffect(mode: state.mode, period: state.period)
            case .deleteTapped:
                guard state.mode == .update else { return .none }
                state.isLoading = true
                return .task(Action.deleteReceived) { [id = state.period.id] in
                    try await dataFetcher.delete(id)
                }
            case .dateChanged(let date):
                if state.mode == .create {
                    let source = state.period
                    state.period = Period(festivalId: source.festivalId, title: source.title, date: date, start: source.start, end: source.end)
                }
                return .none
            case .saveReceived(.failure(let error)),
                .deleteReceived(.failure(let error)):
                state.isLoading = false
                state.alert = Alert.error(error.localizedDescription)
                return .none
            default:
                return .none
            }
        }
        .ifLet(\.$alert, action: \.alert)
    }
    
    private func saveEffect(mode: Mode, period: Period) -> Effect<Action> {
        .task(Action.saveReceived) {
            switch mode {
            case .create:
                try await dataFetcher.create(period)
            case .update:
                try await dataFetcher.update(period)
            }
        }
    }
}

extension PeriodEditFeature.State {
    static func update(_ period: Period) -> Self {
        .init(
            mode: .update,
            period: period
        )
    }
    
    static func create(_ festivalId: String) -> Self {
        .init(
            mode: .create,
            period: Period(
                id: UUID().uuidString,
                festivalId: festivalId,
                title: "",
                date: .now,
                start: .init(hour: 9, minute: 0),
                end: .init(hour: 12, minute: 0)
            )
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
