//
//  AdminRegionFeature.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/05/09.
//

import ComposableArchitecture

@Reducer
struct AdminRegionFeature {
    
    @ObservableState
    struct State: Equatable {
        var region: Region
    }
    
    @CasePathable
    enum Action: Equatable {
        
    }
    
    var body: some ReducerOf<AdminRegionFeature> {
        
    }
}
