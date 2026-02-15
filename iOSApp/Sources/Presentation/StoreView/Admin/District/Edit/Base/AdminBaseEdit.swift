//
//  AdminBaseEdit.swift
//  MaTool
//
//  Created by 松下和也 on 2025/04/16.
//

import ComposableArchitecture
import MapKit
import Shared

@Reducer
struct AdminBaseEdit {
    
    @ObservableState
    struct State: Equatable {
        var coordinate: Coordinate?
        var region: MKCoordinateRegion?
        init(base: Coordinate){
            self.coordinate = base
            self.region = makeRegion(origin: base, spanDelta: spanDelta)
        }
        init(origin: Coordinate){
            self.region = makeRegion(origin: origin, spanDelta: spanDelta)
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
    
    @Dependency(\.dismiss) var dismiss
    
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
                return .dismiss
            case .doneTapped:
                return .none
            case .clearTapped:
                state.coordinate = nil
                return .none
            }
        }
    }
}
