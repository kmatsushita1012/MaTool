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
        let origin: Coordinate
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
        
        init(route: PublicRoute?, location: PublicLocation?, origin: Coordinate){
            self.route = route
            self.location = location
            self.origin = origin
            if let location = location{
                self.region = makeRegion(origin: location.coordinate, spanDelta: spanDelta)
            }else if let route = route,
                     !route.points.isEmpty{
                self.region = makeRegion(route.points.map{ $0.coordinate })
            } else {
                self.region = makeRegion(origin: origin, spanDelta: spanDelta)
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

extension PublicRouteMap.State {
    private func filterPoints(_ route: PublicRoute)-> [Point] {
        var newPoints:[Point] = []
        if let firstPoint = route.points.first,
           firstPoint.title == nil {
            let tempFirst = Point(id: firstPoint.id, coordinate: firstPoint.coordinate, title: "出発", time: route.start, shouldExport: true)
            newPoints.append(tempFirst)
        }
        newPoints.append(contentsOf: route.points.filter{ $0.title != nil })
        if route.points.count >= 2,
           let lastPoint = route.points.last,
           lastPoint.title == nil {
            let tempLast = Point(id: lastPoint.id, coordinate: lastPoint.coordinate, title: "到着", time: route.goal, shouldExport: true)
            newPoints.append(tempLast)
        }
        return newPoints
    }
}
