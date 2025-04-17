//
//  RoutePageFeature.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/04/05.
//


import ComposableArchitecture

@Reducer
struct RoutePublicPageFeature{
    
    @Dependency(\.remoteClient) var remoteClient
    
    @ObservableState
    struct State: Equatable{
        var districtId: String
        var date: SimpleDate
        var title: String
        var route: RouteDetailFeature.State
        var location: LocationFeature.State
    }
    
    enum Action: Equatable{
        case loaded
        case route(RouteDetailFeature.Action)
        case location(LocationFeature.Action)
    }
    
    var body: some ReducerOf<RoutePublicPageFeature> {
        Scope(state: \.route, action: \.route){ RouteDetailFeature() }
        Scope(state: \.location, action: \.location){ LocationFeature() }
        Reduce{ state, action in
            switch action {
            case .loaded:
                return .run { [districtId = state.districtId, date = state.date, title = state.title] send in
                    let routeResult = await self.remoteClient.getRouteDetail(districtId,date,title)
                    let locationResult = await self.remoteClient.getLocation(districtId)
                    
                    await send(.route(.received( routeResult)))
                    await send(.location(.received( locationResult)))
                }
                
            case .route:
                return .none
            case .location:
                return .none
            }
        }
    }
}

