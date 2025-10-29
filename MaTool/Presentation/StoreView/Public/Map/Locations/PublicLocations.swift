//
//  PublicLocations.swift
//  MaTool
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
        case floatFocusSelected(LocationInfo)
        case userFocusTapped
        case userLocationReceived(Coordinate)
        case reloadTapped
        case locationsReceived(Result<[LocationInfo], APIError>)
    }
    
    @Dependency(\.apiRepository) var apiRepository
    @Dependency(\.locationProvider) var locationProvider
    
    var body: some ReducerOf<PublicLocations> {
        BindingReducer()
        Reduce{ state, action in
            switch action {
            case .binding(_):
                return .none
            case .locationTapped(let value):
                state.detail = value
                return .none
            case .floatFocusSelected(let value):
                state.$mapRegion.withLock { $0 = makeRegion(origin: value.coordinate, spanDelta: spanDelta)}
                return .none
            case .reloadTapped:
                return .run{ [id = state.regionId ]send in
                    let result = await apiRepository.getLocations(id)
                    await send(.locationsReceived(result))
                }
            case .locationsReceived(.success(let value)):
                state.locations = value
                return .none
            case .locationsReceived(.failure(_)):
                return .none
            case .userLocationReceived(let value):
                state.$mapRegion.withLock { $0 = makeRegion(origin: value, spanDelta: spanDelta)}
                return .none
            case .userFocusTapped:
                return .run{ send in
                    let result = await locationProvider.getLocation()
                    guard let coordinate = result.value?.coordinate  else { return }
                    await send(.userLocationReceived(Coordinate.fromCL(coordinate)))
                }
            }
        }
    }
}
