//
//  Home.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/04/20.
//

import ComposableArchitecture

@Reducer
struct Settings {
    @ObservableState
    struct State: Equatable {
    }

    @CasePathable
    enum Action:Equatable {
        case homeTapped
    }

    var body: some ReducerOf<Settings> {
        Reduce{ state,action in
            return .none
        }
    }
}
