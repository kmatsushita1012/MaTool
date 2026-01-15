//
//  PublicLocations.swift
//  MaTool
//
//  Created by 松下和也 on 2025/05/04.
//

import ComposableArchitecture
import MapKit
import Shared
import SQLiteData

@Reducer
struct PublicLocations {
    @ObservableState
    struct State:Equatable {
        @Selection struct Float: Equatable {
            let district: District
            let location: FloatLocation
        }
        
        let festival: Festival
        @FetchAll private var floats: [Float]
        
        var floatAnnotations: [FloatCurrentAnnotation] { floats.map{ FloatCurrentAnnotation($0.district.name, location: $0.location) } }
        
        @Shared var mapRegion: MKCoordinateRegion
        var detail: FloatLocation?
    }
    
    @CasePathable
    enum Action: Equatable, BindableAction {
        case binding(BindingAction<State>)
        case locationTapped(FloatCurrentAnnotation)
        case floatFocusSelected(FloatCurrentAnnotation)
        case userFocusTapped
        case userLocationReceived(Coordinate)
        case reloadTapped
    }
    
    @Dependency(\.locationProvider) var locationProvider
    @Dependency(LocationDataFetcherKey.self) var dataFetcher
    
    var body: some ReducerOf<PublicLocations> {
        BindingReducer()
        Reduce{ state, action in
            switch action {
            case .binding(_):
                return .none
            case .locationTapped(let annotation):
                state.detail = annotation.location
                return .none
            case .floatFocusSelected(let annotation):
                state.$mapRegion.withLock { $0 = makeRegion(origin: annotation.location.coordinate, spanDelta: spanDelta)}
                return .none
            case .reloadTapped:
                return .run{ [id = state.festival.id ] send in
                    try? await dataFetcher.fetchAll(festivalId: id)
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
            }
        }
    }
}

extension PublicLocations.State {
    init(_ festival: Festival, mapRegion: Shared<MKCoordinateRegion>){
        self.festival = festival
        self._floats = FetchAll(
            FloatLocation
                .join(District.where{ $0.festivalId == festival.id }, on: { $0.districtId.eq($1.id) })
                .select{ Float.Columns(district: $1, location: $0) })
        self._mapRegion = mapRegion
    }
}

extension PublicLocations.State.Float: Identifiable, Hashable {
    var id: String { self.location.id }
}
