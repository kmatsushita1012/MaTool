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
        var isReissue: Bool = false
        var isLoading: Bool = false
        @Presents var alert: AlertFeature.State?
        @Presents var reissueConfirmAlert: AlertFeature.State?
    }
    @CasePathable
    enum Action: Equatable, BindableAction {
        case binding(BindingAction<State>)
        case createTapped
        case reissueConfirmTapped
        case cancelTapped
        case createReceived(VoidTaskResult)
        case alert(PresentationAction<AlertFeature.Action>)
        case reissueConfirmAlert(PresentationAction<AlertFeature.Action>)
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
                guard !state.name.isEmpty, !state.email.isEmpty else {
                    return .none
                }
                if state.isReissue {
                    state.reissueConfirmAlert = AlertState {
                        TextState("本当に再発行しますか？")
                    } actions: {
                        ButtonState(role: .destructive, action: .okTapped) {
                            TextState("再発行する")
                        }
                        ButtonState(role: .cancel) {
                            TextState("キャンセル")
                        }
                    } message: {
                        TextState("アカウントの再登録が必要です。")
                    }
                    return .none
                }
                state.isLoading = true
                return createEffect(state)
            case .reissueConfirmTapped:
                guard !state.name.isEmpty, !state.email.isEmpty else {
                    return .none
                }
                state.isLoading = true
                return createEffect(state)
            case .reissueConfirmAlert(.presented(.okTapped)):
                state.reissueConfirmAlert = nil
                return .send(.reissueConfirmTapped)
            case .reissueConfirmAlert:
                state.reissueConfirmAlert = nil
                return .none
            case .cancelTapped:
                return .dismiss
            case .createReceived(.success):
                state.isLoading = false
                return .none
            case .createReceived(.failure(let error)):
                state.isLoading = false
                state.alert = AlertFeature.error(error.localizedDescription)
                return .none
            case .alert:
                state.alert = nil
                return .none
            }
        }
        .ifLet(\.$alert, action: \.alert)
        .ifLet(\.$reissueConfirmAlert, action: \.reissueConfirmAlert)
    }

    private func createEffect(_ state: State) -> Effect<Action> {
        .task(Action.createReceived) { [state] in
            try await dataFetcher.create(
                name: state.name,
                email: state.email,
                festivalId: state.festivalId,
                reissue: state.isReissue
            )
            await dismiss()
        }
    }
}
