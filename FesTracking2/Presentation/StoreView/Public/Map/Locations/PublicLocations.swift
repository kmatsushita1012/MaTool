//
//  PublicLocations.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/05/04.
//

import ComposableArchitecture
import MapKit

@Reducer
struct PublicLocations {
    @ObservableState
    struct State:Equatable {
        let regionId: String
        var locations: [LocationInfo]
        @Shared var mapRegion: MKCoordinateRegion
        var detail: LocationInfo?
    }
    
    @CasePathable
    enum Action: Equatable, BindableAction {
        case binding(BindingAction<State>)
        case locationTapped(LocationInfo)
        case updateTapped
        case locationsReceived(Result<[LocationInfo], ApiError>)
    }
    
    @Dependency(\.apiRepository) var apiRepository
    
    var body: some ReducerOf<PublicLocations> {
        BindingReducer()
        Reduce{ state, action in
            switch action {
            case .binding(_):
                return .none
            case .locationTapped(let value):
                state.detail = value
                return .none
            case .updateTapped:
                return .none
            case .locationsReceived(.success(let value)):
                state.locations = value
                return .run{ [id = state.regionId]send in
                    let result = await apiRepository.getLocations(id, "")
                    await send(.locationsReceived(result))
                }
            case .locationsReceived(.failure(let error)):
                return .none
            }
        }
    }
}
