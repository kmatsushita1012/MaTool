//
//  PerformanceAdminFeature.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/04/17.
//

import SwiftUI
import ComposableArchitecture

@Reducer
struct PerformanceAdminFeature{
    @ObservableState
    struct State: Equatable{
        var item: Performance = Performance(id: UUID().uuidString)
    }
    
    enum Action: BindableAction, Equatable{
        case binding(BindingAction<State>)
        case doneTapped
        case cancelTapped
    }
    
    var body: some ReducerOf<PerformanceAdminFeature>{
        BindingReducer()
        Reduce{ state, action in
            switch action {
            case .binding:
                return .none
            case .doneTapped:
                return .none
            case .cancelTapped:
                return .none
            }
        }
    }
}
