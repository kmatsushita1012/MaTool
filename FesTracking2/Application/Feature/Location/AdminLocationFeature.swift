//
//  LocationFeature.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/04/05.
//

import ComposableArchitecture
import CoreLocation

@Reducer
struct AdminLocationFeature{
    
    @ObservableState
    struct State:Equatable{
        let id: String
        var location: Location?
        var isTracking: Bool
        var isLoading: Bool = false
        var history: [Status] = []
        var selectedInterval: Int = 1
        let intervals = [1,2,3,4,5,10,15,20,30,60]
    }
    
    @CasePathable
    enum Action:BindableAction, Equatable{
        case onAppear
        case onDisappear
        case binding(BindingAction<State>)
        case toggleChanged(Bool)
        case historyUpdated([Status])
        case dismissTapped
    }
    
    @Dependency(\.apiClient) var apiClient
    @Dependency(\.locationClient) var locationClient
    @Dependency(\.locationSharingUseCase) var usecase
    
    var body: some ReducerOf<AdminLocationFeature> {
        BindingReducer()
        Reduce{state, action in
            switch action{
            case .onAppear:
                state.selectedInterval = usecase.interval
                state.history = usecase.locationHistory
                return .run { send in
                    for await history in usecase.historyStream {
                        await send(.historyUpdated(history))
                    }
                }
                .cancellable(id: "HistoryStream", cancelInFlight: true)
            case .onDisappear:
                return .cancel(id: "HistoryStream")
            case .binding:
                return .none
            case .toggleChanged(let value):
                state.isTracking = value
                if(value){
                    usecase.startTracking(id: "掛川祭_城北町", interval: state.selectedInterval)
                }else{
                    usecase.stopTracking(id: "掛川祭_城北町")
                }
                return .none
            case .historyUpdated(let history):
                state.history = history
                return .none
            case .dismissTapped:
                return .cancel(id: "HistoryStream")
            }
        }
    }
    
}
