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
            route.text(format: "D m/d T")
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
        case exportTapped
        case dismissTapped
    }
    
    var body: some ReducerOf<AdminRouteExport> {
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


