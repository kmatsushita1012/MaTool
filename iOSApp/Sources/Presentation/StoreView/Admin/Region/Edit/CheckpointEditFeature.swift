//
//  CheckpointEditFeature.swift
//  MaTool
//
//  Created by 松下和也 on 2025/06/25.
//

import ComposableArchitecture
import Shared

@Reducer
struct CheckpointEditFeature {
    
    @ObservableState
    struct State: Equatable {
        let title: String
        var item: Checkpoint
    }
    
    @CasePathable
    enum Action: Equatable,BindableAction {
        case binding(BindingAction<State>)
        case cancelTapped
        case doneTapped
    }
    
    @Dependency(\.dismiss) var dismiss
    
    var body: some ReducerOf<CheckpointEditFeature>{
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .binding:
                return .none
            case .cancelTapped:
                return .dismiss
            case .doneTapped:
                return .none
            }
        }
    }
}
