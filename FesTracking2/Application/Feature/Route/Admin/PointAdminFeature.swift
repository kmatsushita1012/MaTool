//
//  PointAdmin.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/03/06.
//

import ComposableArchitecture


@Reducer
struct PointAdminFeature{
    
    @ObservableState
    struct State: Equatable{
        var item: Point
        var showPopover: Bool = false
    }

    enum Action: BindableAction {
        case binding(BindingAction<State>)
        case doneButtonTapped
        case cancelButtonTapped
        case titleFieldFocused
        case titleOptionSelected(String)
    }
    
    var body: some ReducerOf<PointAdminFeature> {
        BindingReducer()
        Reduce { state, action in
            switch action{
            case .binding:
                return .none
            case .doneButtonTapped:
                return .none
            case .cancelButtonTapped:
                return .none
            case .titleFieldFocused:
                state.showPopover = true
                return .none
            case .titleOptionSelected(let option):
                state.item.title = option
                state.showPopover = false
                return .none
            }
        
        }
    }
}
