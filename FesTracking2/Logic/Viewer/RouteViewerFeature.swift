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


struct RouteViewerState: Equatable {
    var route: Route
    var isLoading: Bool = false
    var errorMessage: String?
}

enum RouteViewerAction: Equatable {
    case fetchRoute(UUID)
    case fetchRouteResponse(Result<Route, RemoteError>)
}

@Reducer
struct RouteViewerFeature{
    
    @Dependency(\.remoteClient) var remoteClient
    
    var body: some Reducer<RouteViewerState, RouteViewerAction> {
//        Store(initialState: RouteState(route: Route(from: "")), reducer: RouteReducer())
        Reduce { state, action in
            switch action {
            case .fetchRoute(let id):
                state.isLoading = true
                state.errorMessage = nil
                return .run {[] send in
                    let result = await self.remoteClient.getRoute(id)
                    await send(.fetchRouteResponse(result))
                }
            case .fetchRouteResponse(.success(let route)):
                state.isLoading = false
                state.route = route
                return .none
                
            case .fetchRouteResponse(.failure(let error)):
                state.isLoading = false
                state.errorMessage = error.localizedDescription
                return .none
            }
        }
    }
}
