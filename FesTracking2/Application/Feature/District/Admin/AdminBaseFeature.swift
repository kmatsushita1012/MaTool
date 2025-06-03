//
//  AdminBaseFeature.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/04/16.
//

import ComposableArchitecture

@Reducer
struct AdminBaseFeature {
    
    @ObservableState
    struct State: Equatable {
        var coordinate: Coordinate?
    }
    @CasePathable
    enum Action: Equatable{
        case mapTapped(Coordinate)
        case cancelTapped
        case doneTapped
    }
    
    var body: some ReducerOf<AdminBaseFeature>{
        Reduce { state, action in
            switch(action){
            case .mapTapped(let coordinate):
                state.coordinate = coordinate
                return .none
            case .cancelTapped:
                state.coordinate = nil
                return .none
            case .doneTapped:
                return .none
            }
        }
    }
}
