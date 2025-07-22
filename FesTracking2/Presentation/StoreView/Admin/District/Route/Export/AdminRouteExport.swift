//
//  AdminRouteExport.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/05/08.
//

import ComposableArchitecture
import MapKit
import Foundation

@Reducer
struct AdminRouteExport {
    @ObservableState
    struct State: Equatable {
        let route: PublicRoute
        var region: MKCoordinateRegion?
        var points: [Point] {
            filterPoints(route)
        }
        var segments: [Segment] {
            route.segments
        }
        var title: String {
            route.text(format: "m/d T")
        }
        var partialPath: String {
            "\(route.text(format: "D_y-m-d_T"))_part_\(Date().stamp).pdf"
        }
        var wholePath: String {
            "\(route.text(format: "D_y-m-d_T"))_full.pdf"
        }
        
        init(route: PublicRoute){
            self.route = route
            region = makeRegion(route.points.map{ $0.coordinate })
        }
    }
    
    @CasePathable
    enum Action: Equatable, BindableAction {
        case binding(BindingAction<State>)
        case dismissTapped
    }
    
    @Dependency(\.dismiss) var dismiss
    
    var body: some ReducerOf<AdminRouteExport> {
        BindingReducer()
        Reduce{ state, action in
            switch action {
            case .binding:
                return .none
            case .dismissTapped:
                return .run{ _ in
                    await dismiss()
                }
            }
        }
    }
}


extension AdminRouteExport.State {
    private func filterPoints(_ route: PublicRoute)-> [Point] {
        var newPoints:[Point] = []
        if let firstPoint = route.points.first,
            !firstPoint.shouldExport {
            let tempFirst = Point(id: firstPoint.id, coordinate: firstPoint.coordinate, title: "出発", time: route.start, shouldExport: true)
            newPoints.append(tempFirst)
        }
        newPoints.append(contentsOf: route.points.filter{ $0.shouldExport })
        if route.points.count >= 2,
           let lastPoint = route.points.last,
           !lastPoint.shouldExport {
            let tempLast = Point(id: lastPoint.id, coordinate: lastPoint.coordinate, title: "到着", time: route.goal, shouldExport: true)
            newPoints.append(tempLast)
        }
        return newPoints
    }
}
