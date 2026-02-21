//
//  DistrictInfoFeature.swift
//  MaTool
//
//  Created by 松下和也 on 2025/07/27.
//

import ComposableArchitecture
import MapKit
import Shared
import SQLiteData

@Reducer
struct DistrictInfoFeature {
    
    @ObservableState
    struct State: Equatable {
        @FetchOne var district: District
        @FetchAll var performances: [Performance]
        var region: MKCoordinateRegion?
        var isLoading: Bool = false
        var isDismissed:Bool = false
    }
    
    @CasePathable
    enum Action: Equatable, BindableAction {
        case binding(BindingAction<State>)
        case dismissTapped
        case mapTapped
    }
    
    @Dependency(\.dismiss) var dismiss
    
    var body: some ReducerOf<DistrictInfoFeature> {
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
            //　MARK: Homeに移譲
            case .mapTapped:
                state.isLoading = true
                return .none
            }
        }
    }
}

extension DistrictInfoFeature.State {
    init(_ district: District){
        self._district = FetchOne(district)
        self._performances = FetchAll(Performance.where{ $0.districtId == district.id })
        if let base = district.base, district.area.isEmpty{
            region = makeRegion(origin: base, spanDelta: spanDelta)
        }else{
            region = makeRegion(district.area)
        }
    }
}
