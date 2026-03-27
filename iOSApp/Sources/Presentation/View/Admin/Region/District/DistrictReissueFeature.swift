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
        let district: District
        var email: String = ""
        var isLoading: Bool = false
        @Presents var alert: AlertFeature.State?
    }

    @CasePathable
    enum Action: Equatable, BindableAction {
        case binding(BindingAction<State>)
        case reissueTapped
        case cancelTapped
        case reissueReceived(VoidTaskResult)
        case alert(PresentationAction<AlertFeature.Action>)
    }

    @Dependency(DistrictDataFetcherKey.self) var dataFetcher
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
                return .task(Action.reissueReceived) { [state] in
                    try await dataFetcher.reissue(districtId: state.district.id, email: state.email)
                    await dismiss()
                }
            case .cancelTapped:
                return .dismiss
            case .reissueReceived(.success):
                state.isLoading = false
                return .none
            case .reissueReceived(.failure(let error)):
                state.isLoading = false
                state.alert = AlertFeature.error(error.localizedDescription)
                return .none
            case .alert:
                state.alert = nil
                return .none
            }
        }
        .ifLet(\.$alert, action: \.alert)
    }
}

