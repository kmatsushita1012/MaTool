//
//  AppFeature.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/04/20.
//

import ComposableArchitecture
import Foundation

@Reducer
struct SettingsFeature {
    @ObservableState
    struct State: Equatable {
    }

    @CasePathable
    enum Action:Equatable {
        case homeTapped
    }

    var body: some ReducerOf<Self> {

    }
}
