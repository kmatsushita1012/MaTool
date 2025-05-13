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
        case adminDistrict(AdminDistrictFeature)
        case adminRegion(AdminRegionFeature)
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
        case awsInitReceived(Result<UserRole,AWSCognitoError>)
        case adminDistrictReceived(district: Result<PublicDistrict,ApiError>, routes: Result<[RouteSummary],ApiError>)
        case adminRegionReceived(region: Result<Region,ApiError>, districts: Result<[PublicDistrict],ApiError>)
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
                    await send(.awsInitReceived(result))
                }
            case .awsInitReceived(.success(let value)):
                state.isLoggedIn = value
                return .none
            case .awsInitReceived(.failure(_)):
                state.isLoggedIn = .guest
                return .none
            case .adminDistrictReceived(let districtResult, let routesResult):
                if case let .success(district) = districtResult,
                   case let .success(routes) = routesResult{
                    state.destination = .adminDistrict(AdminDistrictFeature.State(district: district, routes: routes))
                }else{
                    //Todo
                }
                return .none
            case .adminRegionReceived(let regionResult, let districtsResult):
                if case let .success(region) = regionResult,
                   case let .success(districts) = districtsResult{
                    state.destination = .adminRegion(AdminRegionFeature.State(region: region, districts: districts))
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
                    return adminDistrictEffect(id)
                } else if case let .region(id) = state.isLoggedIn {
                    return adminRegionEffect(id)
                } else {
                    state.destination = .login(LoginFeature.State())
                    return .none
                }
            case .settingsTapped:
                state.destination = .settings(SettingsFeature.State())
                return .none
            case .destination(.presented(let childAction)):
                switch childAction {
                case .login(.received(.success(let value))):
                    state.isLoggedIn = value
                    if case let .district(id) = value{
                        return adminDistrictEffect(id)
                    } else if case let .region(id) = value {
                        return adminRegionEffect(id)
                    } else {
                        return .none
                    }
                case .login(.received(.failure(_))):
                    state.isLoggedIn = .guest
                    return .none
                case .adminDistrict(.signOutReceived(.success(_))),
                        .adminRegion(.signOutReceived(.success(_))):
                    state.destination = nil
                    state.isLoggedIn = .guest
                    return .none
                case .route(.homeTapped),
                    .info(.homeTapped),
                    .adminDistrict(.homeTapped),
                    .adminRegion(.homeTapped),
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
    
    func adminDistrictEffect(_ id: String)-> Effect<Action> {
        return .run { send in
            async let districtResult = apiClient.getDistrict(id)
            async let routesResult =  apiClient.getRoutes(id)
            let _ = await (districtResult, routesResult)
            await send(.adminDistrictReceived(district: districtResult, routes: routesResult))
        }
    }
    
    func adminRegionEffect(_ id: String)-> Effect<Action> {
        return .run { send in
            async let regionResult = apiClient.getRegion(id)
            async let districtsResult =  apiClient.getDistricts(id)
            let _ = await (regionResult, districtsResult)
            await send(.adminRegionReceived(region: regionResult, districts: districtsResult))
        }
    }
}

extension AppFeature.Destination.State: Equatable {}
extension AppFeature.Destination.Action: Equatable {}
