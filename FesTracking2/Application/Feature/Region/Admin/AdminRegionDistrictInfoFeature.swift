//
//  AdminRegionDistrictInfoFeature.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/05/12.
//

import ComposableArchitecture

@Reducer
struct AdminRegionDistrictInfoFeature {
    @ObservableState
    struct State: Equatable {
        let district: PublicDistrict
        let routes: [RouteSummary]
    }
    
    @CasePathable
    enum Action: Equatable {
        case dismissTapped
    }
    
    var body: some ReducerOf<AdminRegionDistrictInfoFeature> {
        Reduce{ state, action in
            switch action {
            case .dismissTapped:
                return .none
            }
        }
    }
    
}
