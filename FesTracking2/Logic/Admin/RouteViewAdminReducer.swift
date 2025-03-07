//
//  EditingAdminReducer.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/03/07.
//
import MapKit

struct RouteViewAdminState: Equatable{
    var domainState: RouteDomainAdminState
    var annotations: [MKAnnotation]
    var polylines: [MKPolyline]
}

enum RouteViewAdminAction{
    case setRoute(Route)
    case editPoint(Point)
    case addPoint(Double, Double)
    case undo
    case redo
    case post
    case delete
    case receivedResponse(Result<String,RemoteError>)
}


