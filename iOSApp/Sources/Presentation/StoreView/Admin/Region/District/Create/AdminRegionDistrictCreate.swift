//
//  AdminFestivalDistrictCreate.swift
//  MaTool
//
//  Created by 松下和也 on 2025/05/12.
//

import ComposableArchitecture
import Shared

@Reducer
struct AdminDistrictCreate {
    
    @ObservableState
    struct State: Equatable {
        let festivalId: Festival.ID
        var name: String = ""
        var email: String = ""
        var isLoading: Bool = false
        @Presents var alert: Alert.State?
    }
    @CasePathable
    enum Action: Equatable, BindableAction {
        case binding(BindingAction<State>)
        case createTapped
        case cancelTapped
        case received(VoidResult<APIError>)
        case alert(PresentationAction<Alert.Action>)
    }
    
    @Dependency(DistrictDataFetcherKey.self) var dataFetcher
    @Dependency(\.dismiss) var dismiss
    
    var body: some ReducerOf<AdminDistrictCreate> {
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
                return .run { [state] send in
                    let result = await task{ try await dataFetcher.create(name: state.name, email: state.email, festivalId: state.festivalId) }
                }
            case .cancelTapped:
                return .run { _ in
                    await dismiss()
                }
            case .received(.failure(let error)):
                state.isLoading = false
                state.alert = Alert.error(error.localizedDescription)
                return .none
            case .alert:
                state.alert = nil
                return .none
            default:
                return .none
            }
        }
        .ifLet(\.$alert, action: \.alert)
    }
}
