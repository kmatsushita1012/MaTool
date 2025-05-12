//
//  LocationFeature.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/04/05.
//

import ComposableArchitecture
import CoreLocation

@Reducer
struct LocationAdminFeature{
    
    @ObservableState
    struct State:Equatable{
        let id: String
        var location: Location?
        var isTracking: Bool
        var isLoading: Bool = false
        var history: [Status] = []
    }
    
    @CasePathable
    enum Action:BindableAction, Equatable{
        case onAppear
        case onDisappear
        case binding(BindingAction<State>)
        case toggleChanged(Bool)
        case historyUpdated([Status])
        case dismissButtonTapped
    }
    
    @Dependency(\.apiClient) var apiClient
    @Dependency(\.locationClient) var locationClient
    @Dependency(\.locationSharingUseCase) var usecase
    
    var body: some ReducerOf<LocationAdminFeature> {
        BindingReducer()
        Reduce{state, action in
            switch action{
            case .onAppear:
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
                let interval = 1.0
                if(value){
                    usecase.startTracking(id: "johoku",interval:interval)
                }else{
                    usecase.stopTracking(id: "johoku")
                }
                return .none
            case .historyUpdated(let history):
                state.history = history
                return .none
            case .dismissButtonTapped:
                return .cancel(id: "HistoryStream")
            }
        }
    }
    
}
