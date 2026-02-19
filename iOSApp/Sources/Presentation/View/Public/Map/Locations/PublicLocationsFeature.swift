//
//  PublicLocationsFeature.swift
//  MaTool
//
//  Created by 松下和也 on 2025/05/04.
//

import ComposableArchitecture
import MapKit
import Shared
import SQLiteData

@Reducer
struct PublicLocationsFeature {
    @ObservableState
    struct State:Equatable {

        let festival: Festival
        @FetchAll var floats: [FloatEntry]
        
        @Shared var mapRegion: MKCoordinateRegion
        var detail: FloatEntry?
        @Presents var alert: AlertFeature.State?
    }
    
    @CasePathable
    enum Action: Equatable, BindableAction {
        case binding(BindingAction<State>)
        case floatTapped(FloatEntry)
        case floatFocusSelected(FloatEntry)
        case userFocusTapped
        case userLocationReceived(Coordinate)
        case reloadTapped
        case reloadReceived(VoidTaskResult)
        case alert(PresentationAction<AlertFeature.Action>)
    }
    
    @Dependency(\.locationProvider) var locationProvider
    @Dependency(LocationDataFetcherKey.self) var dataFetcher
    
    var body: some ReducerOf<PublicLocationsFeature> {
        BindingReducer()
        Reduce{ state, action in
            switch action {
            case .binding(_):
                return .none
            case .floatTapped(let entry):
                state.detail = entry
                return .none
            case .floatFocusSelected(let entry):
                state.$mapRegion.withLock { $0 = makeRegion(origin: entry.floatLocation.coordinate, spanDelta: spanDelta)}
                return .none
            case .reloadTapped:
                return .task(Action.reloadReceived) { [state] in
                    try await dataFetcher.fetchAll(festivalId: state.festival.id)
                }
            case .userLocationReceived(let value):
                state.$mapRegion.withLock { $0 = makeRegion(origin: value, spanDelta: spanDelta)}
                return .none
            case .userFocusTapped:
                return .run{ send in
                    let result = await locationProvider.getLocation()
                    guard let coordinate = result.value?.coordinate  else { return }
                    await send(.userLocationReceived(Coordinate.fromCL(coordinate)))
                }
            case .reloadReceived(.failure(let error)):
                state.alert = AlertFeature.error(error.localizedDescription)
                return .none
            default:
                return .none
            }
        }
        .ifLet(\.$alert, action: \.alert)
    }
}

extension PublicLocationsFeature.State {
    init(_ festival: Festival, mapRegion: Shared<MKCoordinateRegion>){
        self.festival = festival
        self._floats = FetchAll(festivalId: festival.id)
        self._mapRegion = mapRegion
        if !self.floats.isEmpty {
            self.$mapRegion.withLock{ $0 = makeRegion(locations: floats.map(keyPath: \.floatLocation), origin: festival.base) }
        }
    }
}
