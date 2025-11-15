//
//  AdminAreaEdit.swift
//  MaTool
//
//  Created by 松下和也 on 2025/04/16.
//

import ComposableArchitecture
import MapKit
import Shared

@Reducer
struct AdminAreaEdit{
    @ObservableState
    struct State:Equatable {
        var coordinates: [Coordinate]
        var region: MKCoordinateRegion?
        init(coordinates: [Coordinate], origin: Coordinate){
            self.coordinates = coordinates
            region = makeRegion(origin: origin, spanDelta: spanDelta)
        }
    }
    
    @CasePathable
    enum Action: Equatable, BindableAction{
        case binding(BindingAction<State>)
        case mapTapped(Coordinate)
        case dismissTapped
        case doneTapped
        case undoTapped
    }
    
    @Dependency(\.dismiss) var dismiss
    
    var body: some ReducerOf<AdminAreaEdit>{
        BindingReducer()
        Reduce { state, action in
            switch(action){
            case .binding:
                return .none
            case .mapTapped(let coordinate):
                state.coordinates.append(coordinate)
                return .none
            case .doneTapped:
                return .none
            case .dismissTapped:
                return .run{ _ in
                    await dismiss()
                }
            case .undoTapped:
                if(!state.coordinates.isEmpty){
                    state.coordinates.removeLast()
                }
                return .none
            }
        }
    }
}
