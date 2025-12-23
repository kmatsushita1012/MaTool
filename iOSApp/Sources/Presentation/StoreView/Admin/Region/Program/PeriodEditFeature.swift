//
//  PeriodEditFeature.swift
//  MaTool
//
//  Created by 松下和也 on 2025/12/07.
//

import ComposableArchitecture
import Shared

@Reducer
struct PeriodEditFeature {
    
    @ObservableState
    struct State: Equatable {
        var period: Period
    }
    
    @CasePathable
    enum Action: Equatable, BindableAction {
        case binding(BindingAction<State>)
        case doneTapped
        case deleteTapped
    }
    
    var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce{ state, action in
            switch action {
            case .binding(_):
                return .none
            case .doneTapped:
                return .none
            case .deleteTapped:
                return .none
            }
        }
    }
}
