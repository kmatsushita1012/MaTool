//
//  DistrictCreateFeature.swift
//  MaTool
//
//  Created by 松下和也 on 2025/05/12.
//

import ComposableArchitecture
import Shared

@Reducer
struct DistrictCreateFeature {
    
    @ObservableState
    struct State: Equatable {
        let festivalId: Festival.ID
        var name: String = ""
        var email: String = ""
        var isLoading: Bool = false
        @Presents var alert: AlertFeature.State?
    }
    @CasePathable
    enum Action: Equatable, BindableAction {
        case binding(BindingAction<State>)
        case createTapped
        case cancelTapped
        case createReceived(VoidAppResult)
        case alert(PresentationAction<AlertFeature.Action>)
    }
    
    @Dependency(DistrictDataFetcherKey.self) var dataFetcher
    @Dependency(\.dismiss) var dismiss
    
    var body: some ReducerOf<DistrictCreateFeature> {
        BindingReducer()
        Reduce{ state, action in
            switch action {
            case .binding:
                return .none
            case .createTapped:
                if state.name.isEmpty || state.email.isEmpty {
                    return .none
                }
                state.isLoading = true
                return createEffect(state)
            case .cancelTapped:
                return .dismiss
            case .createReceived(.success):
                state.isLoading = false
                return .none
            case .createReceived(.failure(let error)):
                state.isLoading = false
                state.alert = AlertFeature.error(error.message)
                return .none
            case .alert:
                state.alert = nil
                return .none
            }
        }
        .ifLet(\.$alert, action: \.alert)
    }

    private func createEffect(_ state: State) -> Effect<Action> {
        .task(Action.createReceived) { [state] in
            try await dataFetcher.create(
                name: state.name,
                email: state.email,
                festivalId: state.festivalId
            )
            await dismiss()
        }
    }
}
