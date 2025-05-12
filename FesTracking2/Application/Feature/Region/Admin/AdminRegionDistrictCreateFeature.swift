//
//  AdminRegionDistrictCreateFeature.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/05/12.
//

import ComposableArchitecture

@Reducer
struct AdminRegionDistrictCreateFeature {
    @ObservableState
    struct State: Equatable {
        
    }
    @CasePathable
    enum Action: Equatable, BindableAction {
        case binding(BindingAction<State>)
        case saveTapped
        case cancelTapped
    }
    var body: some ReducerOf<AdminRegionDistrictCreateFeature> {
        BindingReducer()
        Reduce{ state, action in
            switch action {
            case .binding:
                return .none
            case .saveTapped:
                return .none
            case .cancelTapped:
                return .none
            }
        }
    }
}
