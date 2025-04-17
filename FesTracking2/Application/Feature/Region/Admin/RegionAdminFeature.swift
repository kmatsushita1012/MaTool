//
//  RegionAdminFeature.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/04/17.
//

import ComposableArchitecture

@Reducer
struct RegionAdminFeature {
    @ObservableState
    struct State: Equatable {
        var item: District
    }
    @CasePathable
    enum Action: BindableAction {
        case binding(BindingAction<State>)
        case saveButtonTapped
        case cancelButtonTapped
    }
    var body: some ReducerOf<RegionAdminFeature> {
        BindingReducer()
        Reduce{ state, action in
            switch action {
            case .binding:
                return .none
            case .saveButtonTapped:
                return .none
            case .cancelButtonTapped:
                return .none
            }
        }
    }
}
