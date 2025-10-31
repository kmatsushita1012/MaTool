//
//  FestivalInfo.swift
//  MaTool
//
//  Created by 松下和也 on 2025/07/27.
//

import ComposableArchitecture
import Shared

@Reducer
struct FestivalInfo {
    
    @ObservableState
    struct State: Equatable {
        let item: Festival
    }
    
    @CasePathable
    enum Action: Equatable {
        case dismissTapped
    }
    
    var body: some ReducerOf<FestivalInfo> {
        Reduce{ state,action in
            return .none
        }
    }
}
