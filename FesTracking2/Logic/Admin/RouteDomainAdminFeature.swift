//
//  RouteAdminReducer.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/03/06.
//

import ComposableArchitecture
import Foundation

struct RouteDomainAdminState:Equatable{
    var route: Route
    var stack: Stack<Pair> = Stack()
    var isLoading: Bool = false
    var errorMessage: String? = nil
}

extension RouteDomainAdminState{
    mutating func setRoute(_ route: Route) -> Effect<RouteDomainAdminReducer.Action> {
        self.route = route
        isLoading = false
        errorMessage = nil
        return .none
    }
    mutating func editPoint(_ point: Point) -> Effect<RouteDomainAdminAction> {
        if let index = route.points.firstIndex(where: { $0.id == point.id }) {
            route.points[index] = point
        }
        return .none
    }
    mutating func addPoint(_ latitude: Double,_ longitude: Double) -> Effect<RouteDomainAdminAction> {
        let next = Point(id: UUID(), coordinate: Coordinate(latitude: latitude, longitude: longitude), title: nil, description: nil, time: nil, isPassed: false)
        if let last = route.points.last{
            let segment = Segment(id: UUID(), start: last.coordinate, end: next.coordinate)
            route.segments.append(segment)
        }
        route.points.append(next)
        return .none
    }
    mutating func undo() -> Effect<RouteDomainAdminAction> {
        if(route.points.isEmpty){
            return .none
        }
        let point = route.points.removeLast()
        let segment = route.segments.removeLast()
        let pair = Pair(id: UUID(), point: point, segment: segment)
        stack.push(pair)
        return .none
    }
    mutating func redo() -> Effect<RouteDomainAdminAction> {
        if(stack.isEmpty){
            return .none
        }
        if let pair = stack.pop(){
            route.points.append(pair.point)
            route.segments.append(pair.segment)
        }
        return .none
    }
    mutating func post() -> Effect<RouteDomainAdminAction> {
        @Dependency(\.remoteClient) var remoteClient
        isLoading = true
        errorMessage = nil
        return .run {[route = self.route] send in
            let result = await remoteClient.postRoute(route)
            await send(.receivedResponse(result))
        }
    }
    mutating func delete() -> Effect<RouteDomainAdminAction> {
        @Dependency(\.remoteClient) var remoteClient
        isLoading = true
        errorMessage = nil
        return .run {[route = self.route] send in
            let result = await remoteClient.deleteRoute(route.id)
            await send(.receivedResponse(result))
        }
    }
}

enum RouteDomainAdminAction:Equatable{
    case receivedResponse(Result<String,RemoteError>)
}



struct RouteDomainAdminReducer: Reducer{
    var body: some Reducer<RouteDomainAdminState, RouteDomainAdminAction> {
        Reduce{ state, action in
            switch action {
            case .receivedResponse(.success(_)):
                state.isLoading = false
                return .none
            case let .receivedResponse(.failure(error)):
                state.isLoading = false
                state.errorMessage = error.localizedDescription
                return .none
            }
        
        }
    }
    
}
