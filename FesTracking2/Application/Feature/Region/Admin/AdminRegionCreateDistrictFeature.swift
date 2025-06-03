//
//  AdminRegionDistrictCreateFeature.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/05/12.
//

import ComposableArchitecture

@Reducer
struct AdminRegionDistrictCreateFeature {
    
    @Dependency(\.apiClient) var apiClient
    
    @ObservableState
    struct State: Equatable {
        let region: Region
        var districtName: String = ""
        var email: String = ""
    }
    @CasePathable
    enum Action: Equatable, BindableAction {
        case binding(BindingAction<State>)
        case createTapped
        case cancelTapped
        case postReceived(Result<String,ApiError>)
    }
    var body: some ReducerOf<AdminRegionDistrictCreateFeature> {
        BindingReducer()
        Reduce{ state, action in
            switch action {
            case .binding:
                return .none
            case .createTapped:
                if state.districtName.isEmpty || state.email.isEmpty {
                    return .none
                }
                return .run { send in
                    
                }
            case .cancelTapped:
                return .none
            case .postReceived(.success(_)):
                return .none
            case .postReceived(.failure(_)):
                return .none
            }
        }
    }
}
