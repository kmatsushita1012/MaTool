//
//  PointFeature.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/05/07.
//

import ComposableArchitecture

@Reducer
struct PointFeature {
    @ObservableState
    struct State: Equatable {
        let point: Point
    }
    
    @CasePathable
    enum Action: Equatable {
    }
    var body: some ReducerOf<PointFeature> {}
}
