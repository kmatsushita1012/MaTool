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
import SwiftUI

@Reducer
struct DistrictInfoFeature {
    
    @ObservableState
    struct State: Equatable {
        let districtId: District.ID
        @Shared fileprivate var appState: AppState?
        var appStateDistrict: District? {
            appState?.district(id: districtId)
        }
        @Fallback(select: { (state: DistrictInfoFeature.State) in state.appStateDistrict })
        @ObservationStateIgnored
        var district: District
        let performances: [Performance]
        var colorTheme: ColorScheme?
        var region: MKCoordinateRegion?
    }
    
    @CasePathable
    enum Action: Equatable, BindableAction {
        case binding(BindingAction<State>)
        case colorThemeResolved(ColorScheme)
        case colorThemeSelected(ColorScheme)
    }
    
    var body: some ReducerOf<DistrictInfoFeature> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .binding:
                return .none
            case .colorThemeResolved(let colorTheme):
                guard state.colorTheme == nil else { return .none }
                state.colorTheme = colorTheme
                return .none
            case .colorThemeSelected(let colorTheme):
                state.colorTheme = colorTheme
                return .none
            }
        }
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
