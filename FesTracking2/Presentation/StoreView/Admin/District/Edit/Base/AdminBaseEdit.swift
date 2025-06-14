//
//  AdminBaseEdit.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/04/16.
//

import ComposableArchitecture
import MapKit

@Reducer
struct AdminBaseEdit {
    
    @ObservableState
    struct State: Equatable {
        var coordinate: Coordinate?
        var region: MKCoordinateRegion?
        init(coordinate: Coordinate?){
            self.coordinate = coordinate
            self.region = makeRegion(base: coordinate, spanDelta: spanDelta)
        }
    }
    @CasePathable
    enum Action: Equatable, BindableAction{
        case binding(BindingAction<State>)
        case mapTapped(Coordinate)
        case dismissTapped
        case doneTapped
        case clearTapped
    }
    
    var body: some ReducerOf<AdminBaseEdit>{
        BindingReducer()
        Reduce { state, action in
            switch(action){
            case .binding:
                return .none
            case .mapTapped(let coordinate):
                state.coordinate = coordinate
                return .none
            case .dismissTapped:
                return .none
            case .doneTapped:
                return .none
            case .clearTapped:
                state.coordinate = nil
                return .none
            }
        }
    }
}
