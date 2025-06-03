//
//  AdminAreaFeature.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/04/16.
//

import ComposableArchitecture

@Reducer
struct AdminAreaFeature{
    @ObservableState
    struct State:Equatable {
        var coordinates: [Coordinate]
    }
    
    @CasePathable
    enum Action: Equatable{
        case mapTapped(Coordinate)
        case undoTapped
        case doneTapped
    }
    
    var body: some ReducerOf<AdminAreaFeature>{
        Reduce { state, action in
            switch(action){
            case .mapTapped(let coordinate):
                state.coordinates.append(coordinate)
                return .none
            case .undoTapped:
                if(!state.coordinates.isEmpty){
                    state.coordinates.removeLast()
                }
                return .none
            case .doneTapped:
                return .none
            }
        }
    }
}
