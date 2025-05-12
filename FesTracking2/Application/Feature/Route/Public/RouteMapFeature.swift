//
//  RouteMapFeature.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/05/04.
//

import ComposableArchitecture
import Foundation

@Reducer
struct RouteMapFeature {
    @Reducer
    enum Destination{
        case point(PointFeature)
        case location(LocationFeature)
    }
    
    @ObservableState
    struct State: Equatable {
        let route: PublicRoute?
        let location: PublicLocation?
        @Presents var sheet: Destination.State?
        var points: [Point]? {
            route?.points.filter{ $0.title != nil || $0 == route?.points.first ||  $0 == route?.points.last }
        }
        var segments: [Segment]? {
            route?.segments
        }
    }
    
    @CasePathable
    enum Action: Equatable, BindableAction {
        case binding(BindingAction<State>)
        case pointTapped(Point)
        case locationTapped(PublicLocation)
        case sheet(PresentationAction<Destination.Action>)
    }
    
    var body: some ReducerOf<RouteMapFeature> {
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

extension RouteMapFeature.Destination.State: Equatable {}
extension RouteMapFeature.Destination.Action: Equatable {}

private func filterPoints(_ route: Route) -> [Point] {
    var newPoints:[Point] = []
    if let firstPoint = route.points.first,
        firstPoint.title?.isEmpty ?? false {
        let tempFirst = Point(id: UUID().uuidString, coordinate: firstPoint.coordinate, title: "出発", time: route.start, shouldExport: true)
        newPoints.append(tempFirst)
    }
    newPoints.append(contentsOf: route.points.filter{ $0.title?.isEmpty ?? false })
    if route.points.count >= 2,
       let lastPoint = route.points.last,
       lastPoint.title?.isEmpty ?? false {
        let tempFirst = Point(id: UUID().uuidString, coordinate: lastPoint.coordinate, title: "到着", time: route.goal, shouldExport: true)
        newPoints.append(tempFirst)
    }
    return newPoints
}
