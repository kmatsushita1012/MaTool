//
//  LocationFeature.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/05/07.
//

import ComposableArchitecture

@Reducer
struct LocationFeature {
    @ObservableState
    struct State: Equatable {
        let location: PublicLocation
    }
    
    @CasePathable
    enum Action: Equatable {
        
    }
    var body: some ReducerOf<LocationFeature> {
        
    }
}
