//
//  AdminRouteExportFeature.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/05/08.
//

import ComposableArchitecture
import MapKit
import Foundation

@Reducer
struct AdminRouteExportFeature {
    @ObservableState
    struct State: Equatable {
        let route: Route
        var points: [Point] {
            filterPoints(route)
        }
        var segments: [Segment] {
            route.segments
        }
        var path:String {
            route.title
        }
    }
    @CasePathable
    enum Action: Equatable, BindableAction {
        case binding(BindingAction<State>)
        case exportTapped
        case dismissTapped
    }
    
    var body: some ReducerOf<AdminRouteExportFeature> {
        BindingReducer()
        Reduce{ state, action in
            switch action {
            case .binding(_):
                return .none
            case .exportTapped:
                return .none
            case .dismissTapped:
                return .none
            }
        }
    }
}

private func filterPoints(_ route:Route)-> [Point] {
    var newPoints:[Point] = []
    if let firstPoint = route.points.first,
        !firstPoint.shouldExport {
        let tempFirst = Point(id: UUID().uuidString, coordinate: firstPoint.coordinate, title: "出発", time: route.start, shouldExport: true)
        newPoints.append(tempFirst)
    }
    newPoints.append(contentsOf: route.points.filter{ $0.shouldExport })
    if route.points.count >= 2,
       let lastPoint = route.points.last,
       !lastPoint.shouldExport {
        let tempLast = Point(id: UUID().uuidString, coordinate: lastPoint.coordinate, title: "到着", time: route.goal, shouldExport: true)
        newPoints.append(tempLast)
    }
    return newPoints
}
