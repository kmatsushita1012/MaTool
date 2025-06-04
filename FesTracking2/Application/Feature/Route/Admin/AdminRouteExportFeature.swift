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
        let route: PublicRoute
        var points: [Point] {
            filterPoints(route)
        }
        var segments: [Segment] {
            route.segments
        }
        var title: String {
            route.text(format: "D m/d T")
        }
        var partialPath: String {
            "\(route.text(format: "D_y-m-d_T"))_part_\(Date().stamp).pdf"
        }
        var wholePath: String {
            "\(route.text(format: "D_y-m-d_T"))_full.pdf"
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

private func filterPoints(_ route: PublicRoute)-> [Point] {
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
