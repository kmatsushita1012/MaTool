//
//  AppFeature.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/04/20.
//

import AWSMobileClient
import ComposableArchitecture
import Foundation

@Reducer
struct AppFeature {
    
    @Reducer
    enum Destination {
        case route(RouteFeature)
        case info(InfoFeature)
        case login(LoginFeature)
        case districtAdmin(AdminDistrictFeature)
        case regionAdmin(AdminRegionFeature)
        case settings(SettingsFeature)
    }
    
    @ObservableState
    struct State: Equatable {
        var isLoggedIn: UserRole = .guest
        @Presents var destination: Destination.State?
    }
    
    @Dependency(\.awsCognitoClient) var awsCognitoClient
    @Dependency(\.userDefaultsClient) var userDefaultsClient
    @Dependency(\.apiClient) var apiClient

    @CasePathable
    enum Action:Equatable {
        case onAppear
        case awsReceived(Result<UserRole,AWSCognitoError>)
        case apiReceived(district: Result<PublicDistrict,ApiError>, routes: Result<[RouteSummary],ApiError>)
        case destination(PresentationAction<Destination.Action>)
        case routeTapped
        case infoTapped
        case adminTapped
        case settingsTapped
    }

    var body: some ReducerOf<AppFeature> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                return .run { send in
                    let result = await awsCognitoClient.initialize()
                    await send(.awsReceived(result))
                }
            case .awsReceived(.success(let value)):
                state.isLoggedIn = value
                return .none
            case .awsReceived(.failure(_)):
                state.isLoggedIn = .guest
                return .none
            case .apiReceived(let districtResult, let routesResult):
                if case let .success(district) = districtResult,
                   case let .success(routes) = routesResult{
                    state.destination = .districtAdmin(AdminDistrictFeature.State(district: district.toModel(), routes: routes))
                }else{
                    //Todo
                }
                return .none
            case .routeTapped:
                state.destination = .route(RouteFeature.State())
                return .none
            case .infoTapped:
                state.destination = .info(InfoFeature.State())
                return .none
            case .adminTapped:
                if case let .district(id) = state.isLoggedIn {
                    return districtAdminEffect(id)
                } else if case let .region(id) = state.isLoggedIn {
                    return regionAdminEffect(id)
                } else {
                    state.destination = .login(LoginFeature.State())
                    return .none
                }
            case .settingsTapped:
                state.destination = .settings(SettingsFeature.State())
                return .none
            case .destination(.presented(let child)):
                switch child {
                case .login(.received(.success(let value))):
                    state.isLoggedIn = value
                    if case let .district(id) = value{
                        return districtAdminEffect(id)
                    } else if case let .region(id) = value {
                        return regionAdminEffect(id)
                    } else {
                        return .none
                    }
                case .login(.received(.failure(_))):
                    state.isLoggedIn = .guest
                    return .none
                case .districtAdmin(.signOutReceived(_)):
                    state.destination = nil
                    state.isLoggedIn = .guest
                    return .none
                case .route(.homeTapped),
                    .info(.homeTapped),
                    .districtAdmin(.homeTapped),
                    .login(.homeTapped),
                    .settings(.homeTapped):
                    state.destination = nil
                    return .none
                default:
                    return .none
                }
            case.destination(_):
                return .none
            }
        }
        .ifLet(\.$destination, action: \.destination)
    }
    
    func districtAdminEffect(_ id: String)-> Effect<Action> {
        return .run { send in
            async let districtResult = apiClient.getDistrict(id)
            async let routesResult =  apiClient.getRoutes(id)
            let _ = await (districtResult, routesResult)
            await send(.apiReceived(district: districtResult, routes: routesResult))
        }
    }
    
    func regionAdminEffect(_ id: String)-> Effect<Action> {
        return .run { send in
            async let districtResult = apiClient.getDistrict(id)
            async let routesResult =  apiClient.getRoutes(id)
            let _ = await (districtResult, routesResult)
            await send(.apiReceived(district: districtResult, routes: routesResult))
        }
    }
}

extension AppFeature.Destination.State: Equatable {}
extension AppFeature.Destination.Action: Equatable {}
