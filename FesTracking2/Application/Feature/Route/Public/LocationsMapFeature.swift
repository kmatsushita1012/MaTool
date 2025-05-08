//
//  LocationsMapFeature.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/05/04.
//

import ComposableArchitecture

@Reducer
struct LocationsMapFeature {
    @ObservableState
    struct State:Equatable {
        let locations: [PublicLocation]?
        @Presents var location: LocationFeature.State?
    }
    
    @CasePathable
    enum Action: Equatable,BindableAction {
        case binding(BindingAction<State>)
        case locationTapped(PublicLocation)
        case location(PresentationAction<LocationFeature.Action>)
    }
    
    var body: some ReducerOf<LocationsMapFeature> {
        BindingReducer()
        Reduce{ state, action in
            switch action {
            case .binding(_):
                return .none
            case .locationTapped(let location):
                state.location = LocationFeature.State(location: location)
                return .none
            case .location(_):
                return .none
            }
        }
        .ifLet(\.$location,action:\.location){
            LocationFeature()
        }
    }
}
