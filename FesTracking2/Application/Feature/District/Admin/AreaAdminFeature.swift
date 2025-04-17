//
//  AreaAdminFeature.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/04/16.
//

import ComposableArchitecture

@Reducer
struct AreaAdminFeature{
    @ObservableState
    struct State:Equatable {
        var coordinates: [Coordinate]
    }
    
    @CasePathable
    enum Action{
        case mapTapped(Coordinate)
        case undoButtonTapped
        case doneButtonTapped
    }
    
    var body: some ReducerOf<AreaAdminFeature>{
        Reduce { state, action in
            switch(action){
            case .mapTapped(let coordinate):
                state.coordinates.append(coordinate)
                return .none
            case .undoButtonTapped:
                if(!state.coordinates.isEmpty){
                    state.coordinates.removeLast()
                }
                return .none
            case .doneButtonTapped:
                return .none
            }
        }
    }
}
