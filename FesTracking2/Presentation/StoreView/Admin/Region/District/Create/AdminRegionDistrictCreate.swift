//
//  AdminRegionDistrictCreate.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/05/12.
//

import ComposableArchitecture

@Reducer
struct AdminRegionDistrictCreate {
    
    @ObservableState
    struct State: Equatable {
        let region: Region
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
        case received(Result<String,APIError>)
        case alert(PresentationAction<Alert.Action>)
    }
    
    @Dependency(\.apiRepository) var apiRepository
    @Dependency(\.dismiss) var dismiss
    
    var body: some ReducerOf<AdminRegionDistrictCreate> {
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
                return .run { [region = state.region, name = state.name, email = state.email] send in
                    let result = await apiRepository.postDistrict(region.id, name, email)
                    await send(.received(result))
                }
            case .cancelTapped:
                return .run { _ in
                    await dismiss()
                }
            case .received(.success(_)):
                state.isLoading = false
                return .none
            case .received(.failure(let error)):
                state.isLoading = false
                state.alert = Alert.error("作成に失敗しました。\n\(error.localizedDescription)")
                return .none
            case .alert:
                state.alert = nil
                return .none
            }
        }
        .ifLet(\.$alert, action: \.alert)
    }
}
