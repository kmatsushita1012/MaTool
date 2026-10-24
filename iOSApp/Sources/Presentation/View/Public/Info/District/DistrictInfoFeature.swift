//
//  DistrictInfoFeature.swift
//  MaTool
//
//  Created by 松下和也 on 2025/07/27.
//

import ComposableArchitecture
import MapKit
import Shared

@Reducer
struct DistrictInfoFeature {
    
    @ObservableState
    struct State: Equatable {
        let districtId: District.ID
        @Shared fileprivate var appState: AppState?
        var district: District {
            appState!.festivalState.districts.first { $0.id == districtId }!
        }
        let performances: [Performance]
        var region: MKCoordinateRegion?
        var isLoading: Bool = false
        var isDismissed:Bool = false
    }
    
    @CasePathable
    enum Action: Equatable, BindableAction {
        case binding(BindingAction<State>)
        case dismissTapped
        case mapTapped
        case routeIdReceived(AppResult<Route.ID?>)
    }
    
    @Dependency(\.dismiss) var dismiss
    @Dependency(LoadDistrictStateUseCaseKey.self) var loadDistrictStateUseCase
    
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
                return .task(Action.routeIdReceived) { [districtId = state.districtId, appState = state.$appState] in
                    try await loadDistrictStateUseCase(districtId: districtId, appState: appState).currentRouteId
                }
            case .routeIdReceived(.success):
                state.isLoading = false
                return .none
            case .routeIdReceived(.failure):
                state.isLoading = false
                return .none
            }
        }
    }
}

extension DistrictInfoFeature.State {
    init(_ pack: DistrictPack, appState: Shared<AppState?>){
        self.districtId = pack.district.id
        self._appState = appState
        self.performances = pack.performances
        if let base = district.base, district.area.isEmpty{
            region = makeRegion(origin: base, spanDelta: spanDelta)
        }else{
            region = makeRegion(district.area)
        }
    }
}
