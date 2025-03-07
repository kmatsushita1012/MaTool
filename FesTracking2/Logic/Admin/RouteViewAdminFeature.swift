//
//  EditingAdminReducer.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/03/07.
//
import MapKit
import ComposableArchitecture
import SwiftUI

@Reducer
struct RouteViewAdminFeature{
    struct State: Equatable{
        var domain: RouteDomainAdminReducer.State
        var annotations: [MKAnnotation]
        var polylines: [MKPolyline]
        
        static func == (lhs: State, rhs: State) -> Bool {
            return lhs.domain == rhs.domain
        }
    }
    @CasePathable
    enum Action{
        case setRoute(Route)
        case editPoint(Point)
        case addPoint(Double, Double)
        case undo
        case redo
        case post
        case delete
        case domain(RouteDomainAdminReducer.Action)
    }
    
    @Dependency(\.remoteClient) var remoteClient
    
    var body: some Reducer<State, Action> {
        Scope(state: \.domain, action: \.domain) {
            RouteDomainAdminReducer()
        }
        Reduce{ state, action in
            switch action {
            case let .setRoute(route):
                return state.domain.setRoute(route: route).map(Action.domain)
            case let .editPoint(point):
                
                return .none
            case let .addPoint(latitude, longitude):
                
                return .none
            case .undo:
                return .none
            case .redo:
                
                return .none
            case .post:
                return .none
                //リモートに保存
                
            case .delete:
                return .none
                //リモートから削除
            case .domain(_):
                state.annotations = state.domain.route.points.map { point in
                    let annotation = MKPointAnnotation()
                    annotation.coordinate = CLLocationCoordinate2D(latitude: point.coordinate.latitude, longitude: point.coordinate.longitude)
                    return annotation
                }
                state.polylines = [MKPolyline(coordinates: state.domain.route.points.map { CLLocationCoordinate2D(latitude: $0.coordinate.latitude, longitude: $0.coordinate.longitude) }, count: state.domain.route.points.count)]
                return .none
            }
        }
    }
}



