//
//  AdminRegionCreateDistrictFeature.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/05/12.
//

import ComposableArchitecture

@Reducer
struct AdminRegionCreateDistrictFeature {
    
    @Dependency(\.apiClient) var apiClient
    @Dependency(\.accessToken) var accessToken
    
    @ObservableState
    struct State: Equatable {
        let region: Region
        var name: String = ""
        var email: String = ""
        @Presents var alert: OkAlert.State?
    }
    @CasePathable
    enum Action: Equatable, BindableAction {
        case binding(BindingAction<State>)
        case createTapped
        case cancelTapped
        case received(Result<String,ApiError>)
        case alert(PresentationAction<OkAlert.Action>)
    }
    var body: some ReducerOf<AdminRegionCreateDistrictFeature> {
        BindingReducer()
        Reduce{ state, action in
            switch action {
            case .binding:
                return .none
            case .createTapped:
                if state.name.isEmpty || state.email.isEmpty {
                    return .none
                }
                guard let token = accessToken.value else { return .none }
                return .run { [region = state.region, name = state.name, email = state.email] send in
                    let result = await apiClient.postDistrict(region.id, name, email, token)
                    await send(.received(result))
                }
            case .cancelTapped:
                return .none
            case .received(.success(_)):
                return .none
            case .received(.failure(let error)):
                state.alert = OkAlert.make("作成に失敗しました。\n\(error.localizedDescription)")
                return .none
            case .alert(.presented(.okTapped)):
                state.alert = nil
                return .none
            case .alert:
                return .none
            }
        }
        .ifLet(\.$alert, action: \.alert)
    }
}
