//
//  DistrictPickerFeature.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/05/03.
//

import ComposableArchitecture

@Reducer
struct PickerFeature<T: Equatable & Identifiable & Hashable> {
    @ObservableState
    struct State: Equatable {
        var selected: T?
        var items: [T]
        var isExpanded: Bool = false
        var others: [T] {
            if let selected = selected {
                items.filter { $0.id != selected.id }
            } else {
                items
            }
        }
        
        init(items:[T]){
            self.items = items
            self.selected = items.first
        }
        
        init(items:[T], selected:T){
            self.items = items
            self.selected = selected
        }
    }
    
    @CasePathable
    enum Action: Equatable, BindableAction {
        case binding(BindingAction<State>)
        case selected(T)
        case toggleTapped
    }
    
    var body: some ReducerOf<PickerFeature> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .binding:
                return .none
            case .selected(let item):
                state.selected = item
                state.isExpanded = false
                return .none
            case .toggleTapped:
                state.isExpanded = !state.isExpanded
                return .none
            }
        }
    }
}
