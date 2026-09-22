import iOSShared
import Application
import View
//
//  LocationTrackingFeature.swift
//  MaTool
//
//  Created by 松下和也 on 2025/04/05.
//

import ComposableArchitecture
import CoreLocation
import Shared

@Reducer
struct LocationTrackingFeature{
    
    @ObservableState
    struct State:Equatable{
        let id: String
        var location: FloatLocation?
        var isTracking: Bool
        var isLoading: Bool = false
        var history: [Status] = []
        var selectedInterval: Interval = Interval.sample
        let intervals = Interval.options
        
        var isPickerEnabled: Bool {
            !isTracking
        }
    }
    
    @CasePathable
    enum Action:BindableAction, Equatable{
        case onAppear
        case binding(BindingAction<State>)
        case historyUpdated([Status])
        case dismissTapped
    }
    
    @Dependency(\.locationService) var locationService
    @Dependency(\.dismiss) var dismiss
    
    var body: some ReducerOf<LocationTrackingFeature> {
        BindingReducer()
        Reduce{state, action in
            switch action{
            case .onAppear:
                return .run { send in
                    await locationService.requestPermission()
                    let initial = await locationService.getLocationHistory()
                    await send(.historyUpdated(initial))
                    // 以降の更新を購読
                    for await history in await locationService.historyStream() {
                        await send(.historyUpdated(history))
                    }
                }
                .cancellable(id: "HistoryStream", cancelInFlight: true)
            case .binding(\.isTracking):
                
                return .run{ [
                    id = state.id,
                    isTracking = state.isTracking,
                    interval = state.selectedInterval
                ] send in
                    if(isTracking){
                        await locationService.start(id: id, interval: interval)
                    }else{
                        await locationService.stop(id: id)
                    }
                }
            case .binding:
                return .none
            case .historyUpdated(let history):
                state.history = history
                return .none
            case .dismissTapped:
                return .dismiss
            }
        }
    }
}

