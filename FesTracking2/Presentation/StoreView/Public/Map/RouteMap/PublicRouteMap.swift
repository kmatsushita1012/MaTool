//
//  PublicRouteMap.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/05/04.
//

import Foundation
import ComposableArchitecture
import MapKit

@Reducer
struct PublicRouteMap {
    @Reducer
    enum Destination{
        case point(PointFeature)
        case location(LocationFeature)
    }
    
    @ObservableState
    struct State: Equatable {
        let route: PublicRoute?
        let location: PublicLocation?
        var region: MKCoordinateRegion?
        @Presents var sheet: Destination.State?
        var points: [Point]? {
            if let route = route{
                filterPoints(route)
            }else{
                nil
            }
        }
        var segments: [Segment]? {
            route?.segments
        }
        
        init(route: PublicRoute?, location: PublicLocation?){
            self.route = route
            self.location = location
            if let location = location{
                self.region = makeRegion(base: location.coordinate, spanDelta: spanDelta)
            }else if let route = route{
                self.region = makeRegion(route.points.map{ $0.coordinate })
            }
        }
    }
    
    @CasePathable
    enum Action: Equatable, BindableAction {
        case binding(BindingAction<State>)
        case pointTapped(Point)
        case locationTapped(PublicLocation)
        case sheet(PresentationAction<Destination.Action>)
    }
    
    var body: some ReducerOf<PublicRouteMap> {
        BindingReducer()
        Reduce{ state, action in
            switch action {
            case .binding(_):
                return .none
            case .pointTapped(let point):
                state.sheet = .point(PointFeature.State(point: point))
                return .none
            case .locationTapped(let location):
                state.sheet = .location(LocationFeature.State(location: location))
                return .none
            case .sheet(_):
                return .none
            }
        }
        .ifLet(\.$sheet, action: \.sheet)
    }
}

extension PublicRouteMap.Destination.State: Equatable {}
extension PublicRouteMap.Destination.Action: Equatable {}

