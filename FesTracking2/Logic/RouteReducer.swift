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

@Reducer
struct RouteReducer{
//    @Dependency(\.remoteClient)var remoteClient
    var remoteClient: RemoteClient
    
    struct State: Equatable {
        var route: Route
        var isLoading: Bool = false
        var errorMessage: String?
    }

    enum Action: Equatable {
        case fetchRoute(UUID)
        case fetchRouteResponse(Result<Route, RemoteError>)
    }

    struct Environment {
        var mainQueue: AnySchedulerOf<DispatchQueue>
        var remoteClient: RemoteClient
    }
    
    func reduce(into state: inout State, action: Action, environment: Environment) -> Effect<Action> {
            switch action {
            case let .fetchRoute(id):
                state.isLoading = true
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
