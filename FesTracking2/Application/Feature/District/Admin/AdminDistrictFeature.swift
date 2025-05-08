//
//  AdminDistrictFeature.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/04/17.
//

import ComposableArchitecture

@Reducer
struct AdminDistrictFeature {
    
    @Dependency(\.apiClient) var apiClient
    @Dependency(\.locationSharingUseCase) var usecase
    @Dependency(\.awsCognitoClient) var awsCognitoClient
    
    @Reducer
    enum Destination {
        case info(DistrictInfoAdminFeature)
        case route(AdminRouteInfoFeature)
        case location(LocationAdminFeature)
    }
    
    @ObservableState
    struct State:Equatable {
        var district: District
        var routes: [RouteSummary]
        @Presents var destination: Destination.State?
    }
    
    @CasePathable
    enum Action:Equatable {
        case onInfo
        case onRouteAdd
        case onRouteEdit(RouteSummary)
        case onRouteDelete(RouteSummary)
        case getDistrictReceived(Result<PublicDistrict,ApiError>)
        case getRoutesReceived(Result<[RouteSummary],ApiError>)
        case deleteRouteReceived(Result<String,ApiError>)
        case onLocation
        case destination(PresentationAction<Destination.Action>)
        case onSignOut
        case signOutReceived(Result<Bool,AWSCognitoError>)
        case homeTapped
    }
    
    
    var body: some ReducerOf<AdminDistrictFeature> {
        Reduce{state,action in
            print("district admin destination \(state.destination != nil)")
            switch action {
            case .onInfo:
                state.destination = .info(DistrictInfoAdminFeature.State(item: state.district))
                return .none
            case .onRouteAdd:
                state.destination = .route(AdminRouteInfoFeature.State(mode: .create(id: state.district.id)))
                return .none
            case .onRouteEdit(let route):
                state.destination = .route(AdminRouteInfoFeature.State(mode: .edit(id: route.districtId, date: route.date, title: route.title)))
                return .none
            case .onRouteDelete(let route):
                return .run {[route = route] send in
                    let result = await apiClient.deleteRoute(route.districtId, route.date, route.title,"")
                    await send(.deleteRouteReceived(result))
                }
            case .getDistrictReceived(.success(let value)):
                state.district = value.toModel()
                return .none
            case .getRoutesReceived(.success(let value)):
                state.routes = value
                return .none
            case .deleteRouteReceived(.success(_)):
                return .run {[id = state.district.id] send in
                    let result = await apiClient.getRoutes(id)
                    await send(.getRoutesReceived(result))
                }
            case .onLocation:
                state.destination = .location(LocationAdminFeature.State(id: state.district.id, isTracking: usecase.isTracking))
                return .none
            case .destination(.presented(let destination)):
                switch destination {
                case .info(.cancelButtonTapped),
                        .route(.cancelButtonTapped),.location(.dismissButtonTapped):
                    state.destination = nil
                    return .none
                case .info(.postReceived(.success(_))),
                        .route(.postReceived(.success(_))):
                    state.destination = nil
                    return .merge(
                        .run {[id = state.district.id] send in
                            let result = await apiClient.getDistrict(id)
                            await send(.getDistrictReceived(result))
                        },
                        .run {[id = state.district.id] send in
                            let result = await apiClient.getRoutes(id)
                            await send(.getRoutesReceived(result))
                        }
                    )
                default:
                    return .none
                }
            case .onSignOut:
                return .run { send in
                    let result = await awsCognitoClient.signOut()
                    await send(.signOutReceived(result))
                }
            case .signOutReceived(.success(_)):
                return .none
            case .signOutReceived(.failure(_)):
                return .none
            case .getDistrictReceived(.failure(_)),.getRoutesReceived(.failure(_)),.deleteRouteReceived(.failure(_)),.destination(.dismiss):
                return .none
            case .homeTapped:
                return .none
            }
        }
        .ifLet(\.$destination, action: \.destination)
    }
}

extension AdminDistrictFeature.Destination.State: Equatable {}
extension AdminDistrictFeature.Destination.Action: Equatable {}
