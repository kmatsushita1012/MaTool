//
//  PointAdmin.swift
//  MaTool
//
//  Created by 松下和也 on 2025/03/06.
//

import ComposableArchitecture
import Shared

@Reducer
struct AdminPointEdit{
    
    @ObservableState
    struct State: Equatable{
        var item: Point
        var showPopover: Bool = false
        var checkpoints: [Checkpoint]
    }
    
    @CasePathable
    enum Action: BindableAction, Equatable {
        case binding(BindingAction<State>)
        case doneTapped
        case moveTapped
        case insertTapped
        case deleteTapped
        case titleFieldFocused
        case titleOptionSelected(Checkpoint)
    }
    
    var body: some ReducerOf<AdminPointEdit> {
        BindingReducer()
        Reduce { state, action in
            switch action{
            case .binding:
                return .none
            case .doneTapped:
                return .none
            case .moveTapped:
               return .none
           case .insertTapped:
               return .none
           case .deleteTapped:
               return .none
            case .titleFieldFocused:
                state.showPopover = true
                return .none
            case .titleOptionSelected(let option):
                state.item.title = option.name
                state.item.description = option.description
                state.showPopover = false
                return .none
            }
        
        }
    }
}


