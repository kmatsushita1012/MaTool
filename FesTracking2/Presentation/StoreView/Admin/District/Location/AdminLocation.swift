//
//  LocationFeature.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/04/05.
//

import ComposableArchitecture
import CoreLocation

@Reducer
struct AdminLocation{
    
    @ObservableState
    struct State:Equatable{
        let id: String
        var location: Location?
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
    
    @Dependency(\.apiRepository) var apiRepository
    @Dependency(\.locationService) var locationService
    @Dependency(\.dismiss) var dismiss
    
    var body: some ReducerOf<AdminLocation> {
        BindingReducer()
        Reduce{state, action in
            switch action{
            case .onAppear:
                state.selectedInterval = locationService.interval
                state.history = locationService.locationHistory
                return .run { send in
                    for await history in locationService.historyStream {
                        await send(.historyUpdated(history))
                    }
                }
                .cancellable(id: "HistoryStream", cancelInFlight: true)
            case .binding(\.isTracking):
                if(state.isTracking){
                    locationService.startTracking(id: state.id, interval: state.selectedInterval)
                }else{
                    locationService.stopTracking(id: state.id)
                }
                return .none
            case .binding:
                return .none
            case .historyUpdated(let history):
                state.history = history
                return .none
            case .dismissTapped:
                return .run{ _ in
                    await dismiss()
                }
            }
        }
    }
}


struct Interval: Equatable, Hashable {
    let label: String
    let value: Int
    
    static let sample = Interval(label: "5分", value: 300)
    static let options = [
        Interval(label: "5秒（確認用）", value: 5),
        Interval(label: "1分", value: 60),
        Interval(label: "2分", value: 120),
        Interval(label: "3分", value: 180),
        Interval(label: "5分", value: 300),
        Interval(label: "10分", value: 600),
        Interval(label: "15分", value: 900)
    ]
}
