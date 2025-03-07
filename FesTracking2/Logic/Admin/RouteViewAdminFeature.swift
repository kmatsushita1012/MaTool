//
//  EditingAdminReducer.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/03/07.
//
import MapKit
import ComposableArchitecture
import SwiftUI

@ObservableState
struct RouteViewAdminState: Equatable{
    var domain: RouteDomainAdminState
    var annotations: [MKAnnotation]
    var polylines: [MKPolyline]
    
    static func == (lhs: RouteViewAdminState, rhs: RouteViewAdminState) -> Bool {
        return lhs.domain == rhs.domain
    }
}
@CasePathable
enum RouteViewAdminAction{
    case setRoute(Route)
    case editPoint(Point)
    case mapLongPressed(CLLocationCoordinate2D)
    case undoButtonTapped
    case redoButtonTapped
    case saveButtonTapped
    case deleteButtonTapped
    case domain(RouteDomainAdminAction)
}

@Reducer
struct RouteViewAdminFeature{
    
    @Dependency(\.remoteClient) var remoteClient
    
    var body: some Reducer<RouteViewAdminState, RouteViewAdminAction> {
        Scope(state: \.domain, action: \.domain) {
            RouteDomainAdminFeature()
        }
        Reduce{ state, action in
            switch action {
            case .setRoute(let route):
                return state.domain.setRoute(route).map( {Action.domain($0)})
            case .editPoint(let point):
                return state.domain.editPoint(point).map( {Action.domain($0)})
            case .mapLongPressed(let coordinate2D):
                let coordinate = Coordinate(latitude: coordinate2D.latitude, longitude: coordinate2D.longitude)
                return state.domain.addPoint(coordinate).map( {Action.domain($0)})
            case .undoButtonTapped:
                return state.domain.undo().map( {Action.domain($0)})
            case .redoButtonTapped:
                return state.domain.redo().map( {Action.domain($0)})
            case .saveButtonTapped:
                return state.domain.post().map( {Action.domain($0)})
            case .deleteButtonTapped:
                return .none
            //domainから返却されて更新
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



