//
//  FestivalInfoFeature.swift
//  MaTool
//
//  Created by 松下和也 on 2025/07/27.
//

import ComposableArchitecture
import MapKit
import Shared

@Reducer
struct FestivalInfoFeature {

    @ObservableState
    struct State: Equatable {
        let festival: Festival
        var region: MKCoordinateRegion?
        var isDismissed: Bool = false
        var isLoading: Bool = false
    }
    
    @CasePathable
    enum Action: Equatable, BindableAction {
        case binding(BindingAction<State>)
        case dismissTapped
        case mapTapped
    }
    
    @Dependency(\.dismiss) var dismiss
    
    var body: some ReducerOf<FestivalInfoFeature> {
        BindingReducer()
        Reduce{ state,action in
            switch action {
            case .binding:
                return .none
            case .dismissTapped:
                if #available(iOS 17.0, *) {
                    return .dismiss
                } else {
                    state.isDismissed = true
                    return .none
                }
            case .mapTapped:
                state.isLoading = true
                return .none
            }
        }
    }
}

extension FestivalInfoFeature.State {
    init(item: Festival) {
        self.festival = item
        self.region = makeRegion(origin: item.base, spanDelta: spanDelta)
    }
}
