//
//  InfoFeature.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/05/08.
//

import ComposableArchitecture

@Reducer
struct InfoFeature {
    @ObservableState
    struct State: Equatable {
    }
    
    @CasePathable
    enum Action: Equatable {
        case homeTapped
    }
    var body: some ReducerOf<InfoFeature> {
        
    }
}
