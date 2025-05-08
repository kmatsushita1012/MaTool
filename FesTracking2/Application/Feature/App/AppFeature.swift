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
        case admin(AdminDistrictFeature)
        case settings(SettingsFeature)
        case export(AdminRouteExportFeature)
    }
    
    @ObservableState
    struct State: Equatable {
        var isLoggedIn = false
        @Presents var destination: Destination.State?
    }
    
    @Dependency(\.awsCognitoClient) var awsCognitoClient
    @Dependency(\.userDefaultsClient) var userDefaultsClient
    @Dependency(\.apiClient) var apiClient

    @CasePathable
    enum Action:Equatable {
        case onAppear
        case awsReceived(Result<Bool,AWSCognitoError>)
        case apiReceived(district:Result<PublicDistrict,ApiError>,routes:Result<[RouteSummary],ApiError>)
        case destination(Destination.Action)
        case routeTapped
        case infoTapped
        case adminTapped
        case settingsTapped
        case exportTapped
    }

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                return .run { send in
                    let result = await awsCognitoClient.initialize()
                    print("AWS init \(result)")
                    await send(.awsReceived(result))
                }
            case .awsReceived(.success(let value)):
                state.isLoggedIn = value
                return .none
            case .awsReceived(.failure(_)):
                state.isLoggedIn = false
                return .none
            case .apiReceived(let districtResult, let routesResult):
                if case let .success(district) = districtResult,
                   case let .success(routes) = routesResult{
                    state.destination = .admin(AdminDistrictFeature.State(district: district.toModel(), routes: routes))
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
                if state.isLoggedIn {
                    return fetchApi()
                }else {
                    state.destination = .login(LoginFeature.State())
                    return .none
                }
            case .settingsTapped:
                state.destination = .settings(SettingsFeature.State())
                return .none
            case .exportTapped:
                state.destination = .export(AdminRouteExportFeature.State(route: Route.sample))
                return .none
            case .destination(.login(.received(.success(let value)))):
                state.isLoggedIn = value
                return fetchApi()
            case .destination(.login(.received(.failure(_)))):
                state.isLoggedIn = false
                return .none
            case .destination(.admin(.signOutReceived(_))):
                state.destination = nil
                state.isLoggedIn = false
                return .none
            case .destination(.route(.homeTapped)),
                .destination(.info(.homeTapped)),
                .destination(.admin(.homeTapped)),
                .destination(.login(.homeTapped)),
                .destination(.settings(.homeTapped)),
                .destination(.export(.homeTapped)):
                state.destination = nil
                return .none
            case .destination(_):
                return .none
            }
        }
        .ifLet(\.$destination, action: \.destination)
    }
    
    func fetchApi()-> Effect<Action> {
        return .run { send in
            let result = await awsCognitoClient.getUserId()
            switch result{
            case .success(let id):
                print("AWS UserId \(id)")
                async let districtResult = apiClient.getDistrict(id)
                async let routesResult =  apiClient.getRoutes(id)
                let _ = await (districtResult, routesResult)
                await send(.apiReceived(district: districtResult, routes: routesResult))
            case .failure(let error):
                return
            }
        }
    }
}

extension AppFeature.Destination.State: Equatable {}
extension AppFeature.Destination.Action: Equatable {}
