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

enum RouteDomainAdminAction:Equatable{
    case setRoute(Route)
    case editPoint(Point)
    case addPoint(Double, Double)
    case undo
    case redo
    case post
    case delete
    case receivedResponse(Result<String,RemoteError>)
}

struct RouteDomainAdminReducer: Reducer{
    @Dependency(\.remoteClient) var remoteClient
    
    var body: some Reducer<RouteDomainAdminState, RouteDomainAdminAction> {
        Reduce{ state, action in
            switch action {
            case let .setRoute(route):
                state.isLoading = false
                state.errorMessage = nil
                state.route = route
                return .none
            case let .editPoint(point):
                if let index = state.route.points.firstIndex(where: { $0.id == point.id }) {
                    state.route.points[index] = point
                }
                return .none
            case let .addPoint(latitude, longitude):
                let next = Point(id: UUID(), coordinate: Coordinate(latitude: latitude, longitude: longitude), title: nil, description: nil, time: nil, isPassed: false)
                if let last = state.route.points.last{
                    let segment = Segment(id: UUID(), start: last.coordinate, end: next.coordinate)
                    state.route.segments.append(segment)
                }
                state.route.points.append(next)
                return .none
            case .undo:
                if(state.route.points.isEmpty){
                    return .none
                }
                let point = state.route.points.removeLast()
                let segment = state.route.segments.removeLast()
                let pair = Pair(id: UUID(), point: point, segment: segment)
                state.stack.push(pair)
                return .none
            case .redo:
                if(state.stack.isEmpty){
                    return .none
                }
                if let pair = state.stack.pop(){
                    state.route.points.append(pair.point)
                    state.route.segments.append(pair.segment)
                }
                return .none
            case .post:
                //リモートに保存
                state.isLoading = true
                state.errorMessage = nil
                return .run {[state = state] send in
                    let result = await self.remoteClient.postRoute(state.route)
                    await send(.receivedResponse(result))
                }
            case .delete:
                //リモートから削除
                state.isLoading = true
                state.errorMessage = nil
                return .run {[state = state] send in
                    let result = await self.remoteClient.deleteRoute(state.route.id)
                    await send(.receivedResponse(result))
                }
            case let .receivedResponse(.success(_)):
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
