//
//  RegionInfo.swift
//  MaTool
//
//  Created by 松下和也 on 2025/07/27.
//

import ComposableArchitecture
import Shared

@Reducer
struct RegionInfo {
    
    @ObservableState
    struct State: Equatable {
        let item: Region
    }
    
    @CasePathable
    enum Action: Equatable {
        case dismissTapped
    }
    
    var body: some ReducerOf<RegionInfo> {
        Reduce{ state,action in
            return .none
        }
    }
}
