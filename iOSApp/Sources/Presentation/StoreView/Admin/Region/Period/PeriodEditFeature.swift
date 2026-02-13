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
        case saveReceived(VoidResult<APIError>)
        case deleteReceived(VoidResult<APIError>)
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
                return .run { [id = state.period.id] send in
                    let result = await task{ try await dataFetcher.delete(id) }
                    await send(.deleteReceived(result))
                }
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
        .run { send in
            let result: VoidResult<APIError> = await task{
                switch mode {
                case .create:
                    try await dataFetcher.create(period)
                case .update:
                    try await dataFetcher.update(period)
                }
            }
            await send(.saveReceived(result))
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
}
