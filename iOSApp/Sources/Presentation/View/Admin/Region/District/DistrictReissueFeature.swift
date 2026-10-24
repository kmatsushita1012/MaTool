//
//  DistrictReissueFeature.swift
//  MaTool
//
//  Created by Codex on 2026/03/28.
//

import ComposableArchitecture
import Shared

@Reducer
struct DistrictReissueFeature {
    @ObservableState
    struct State: Equatable {
        let districtId: District.ID
        @Shared fileprivate var appState: AppState?
        var email: String = ""
        var isLoading: Bool = false
        @Presents var alert: AlertFeature.State?

        init(districtId: District.ID, appState: Shared<AppState?> = Shared(value: nil)) {
            self.districtId = districtId
            self._appState = appState
        }
    }

    @CasePathable
    enum Action: Equatable, BindableAction {
        case binding(BindingAction<State>)
        case reissueTapped
        case cancelTapped
        case reissueReceived(VoidAppResult)
        case alert(PresentationAction<AlertFeature.Action>)
    }

    @Dependency(ReissueDistrictUseCaseKey.self) var reissueDistrictUseCase
    @Dependency(\.dismiss) var dismiss

    var body: some ReducerOf<DistrictReissueFeature> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .binding:
                return .none
            case .reissueTapped:
                guard !state.email.isEmpty else {
                    state.alert = AlertFeature.error("メールアドレスを入力してください。")
                    return .none
                }
                state.isLoading = true
                return .task(Action.reissueReceived) { [districtId = state.districtId, email = state.email, appState = state.$appState] in
                    _ = try await reissueDistrictUseCase(
                        districtId: districtId,
                        email: email,
                        appState: appState
                    )
                    await dismiss()
                }
            case .cancelTapped:
                return .dismiss
            case .reissueReceived(.success):
                state.isLoading = false
                return .none
            case .reissueReceived(.failure(let error)):
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
}

