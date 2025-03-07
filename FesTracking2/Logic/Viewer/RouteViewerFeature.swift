//
//  RouteLogic.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/03/02.
//

import ComposableArchitecture
import Foundation
import Dependencies
import DependenciesMacros


struct RouteState: Equatable {
    var route: Route
    var isLoading: Bool = false
    var errorMessage: String?
}

enum RouteAction: Equatable {
    case fetchRoute(UUID)
    case fetchRouteResponse(Result<Route, RemoteError>)
}

@Reducer
struct RouteFeature{
    
    @Dependency(\.remoteClient) var remoteClient
    
    var body: some Reducer<RouteState, RouteAction> {
//        Store(initialState: RouteState(route: Route(from: "")), reducer: RouteReducer())
        Reduce { state, action in
            switch action {
            case let .fetchRoute(id):
                state.isLoading = true
                state.errorMessage = nil
                return .run {[] send in
                    let result = await self.remoteClient.getRoute(id)
                    await send(.fetchRouteResponse(result))
                }
            case let .fetchRouteResponse(.success(route)):
                state.isLoading = false
                state.route = route
                return .none
                
            case let .fetchRouteResponse(.failure(error)):
                state.isLoading = false
                state.errorMessage = error.localizedDescription
                return .none
            }
        }
    }
}
