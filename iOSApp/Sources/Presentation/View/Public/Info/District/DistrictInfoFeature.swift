//
//  DistrictInfoFeature.swift
//  MaTool
//
//  Created by 松下和也 on 2025/07/27.
//

import ComposableArchitecture
import Fallback
import MapKit
import Shared

@Reducer
struct DistrictInfoFeature {
    
    @ObservableState
    struct State: Equatable {
        let districtId: District.ID
        @Shared fileprivate var appState: AppState?
        var appStateDistrict: District? {
            appState?.district(id: districtId)
        }
        @Fallback(\DistrictInfoFeature.State.appStateDistrict)
        @ObservationStateIgnored
        var district: District
        let performances: [Performance]
        var region: MKCoordinateRegion?
    }
    
    @CasePathable
    enum Action: Equatable, BindableAction {
        case binding(BindingAction<State>)
    }
    
    var body: some ReducerOf<DistrictInfoFeature> {
        BindingReducer()
    }
}

extension DistrictInfoFeature.State {
    init(_ pack: DistrictPack, appState: Shared<AppState?>){
        self.districtId = pack.district.id
        self._appState = appState
        self._district = pack.district
        self.performances = pack.performances
        if let base = district.base, district.area.isEmpty{
            region = makeRegion(origin: base, spanDelta: spanDelta)
        }else{
            region = makeRegion(district.area)
        }
    }
}
