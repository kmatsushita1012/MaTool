//
//  DistrictAdminFeature.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/04/17.
//

import ComposableArchitecture

@Reducer
struct DistrictAdminFeature {
    
    @Dependency(\.apiClient) var apiClient
    
    @Reducer
    enum Destination {
        case info(DistrictInfoAdminFeature)
        case route(RouteInfoAdminFeature)
        case location(LocationAdminFeature)
    }
    
    @ObservableState
    struct State {
        var district: District
        var routes: [RouteSummary]
        @Presents var destination: Destination.State?
    }
    
    @CasePathable
    enum Action {
        case loaded(district:Result<District,ApiError>,routes:Result<[RouteSummary],ApiError>)
        case onInfo
        case onRouteAdd
        case onRouteEdit(RouteSummary)
        case onRouteDelete(RouteSummary)
        case onLocation
        case destination(PresentationAction<Destination.Action>)
        case onSignoutTapped
    }
    
    var body: some ReducerOf<DistrictAdminFeature> {
        Reduce{state,action in
            switch action {
            case .loaded(district: let district, routes: let routes):
                if case let .success(value) = district{
                    state.district = value
                }
                if case let .success(value) = routes{
                    state.routes = value
                }
                return .none
            case .onInfo:
                state.destination = .info(DistrictInfoAdminFeature.State(item: state.district))
                return .none
            case .onRouteAdd:
                state.destination = .route(RouteInfoAdminFeature.State(mode: .create(id: state.district.id)))
                return .none
            case .onRouteEdit(let routeSummary):
                state.destination = .route(RouteInfoAdminFeature.State(mode: .edit(id: routeSummary.districtId, date: routeSummary.date, title: routeSummary.title)))
                return .none
            case .onRouteDelete(_):
                return .none
            case .onLocation:
                return .none
            case .destination(.presented(let destination)):
                switch destination {
                case .info(.cancelButtonTapped),
                        .route(.cancelButtonTapped):
                    state.destination = nil
                    return .none
                case .info(.received(.success(_))),
                        .route(.postReceived(_)):
                    state.destination = nil
                    return .run {[id = state.district.id] send in
                        let district = await apiClient.getDistrictDetail(id)
                        let routes = await apiClient.getRouteSummaries(id)
                        await send(.loaded(district: district, routes: routes))
                    }
                default:
                    return .none
                }
            case .destination(_):
                return .none
            case .onSignoutTapped:
                return .none
            }
        }
    }
}
