//
//  Info.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/05/08.
//

import ComposableArchitecture

@Reducer
struct Info {
    @ObservableState
    struct State: Equatable {
    }
    
    @CasePathable
    enum Action: Equatable {
        case homeTapped
    }
    var body: some ReducerOf<Info> {
        Reduce { state,action in
            return .none
        }
    }
}
