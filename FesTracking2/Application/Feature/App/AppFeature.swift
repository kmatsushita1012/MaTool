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
    
    @Dependency(\.apiClient) var apiClient
    @Dependency(\.awsCognitoClient) var awsCognitoClient
    @Dependency(\.accessToken) var accessToken
    
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
        var userRole: UserRole = .guest
        var isAWSLoading: Bool = false
        var isAdminDistrictLoading: Bool = false
        var isAdminRegionLoading: Bool = false
        var isLoading: Bool {
            isAWSLoading || isAdminDistrictLoading || isAdminRegionLoading
        }
        @Presents var destination: Destination.State?
        @Presents var alert: OkAlert.State?
    }
    

    @CasePathable
    enum Action: Equatable {
        case onAppear
        case routeTapped
        case infoTapped
        case adminTapped
        case settingsTapped
        case awsInitializeReceived(Result<String, AWSCognito.Error>)
        case awsUserRoleReceived(Result<UserRole, AWSCognito.Error>, shouldNavigate: Bool)
        case adminDistrictPrepared(Result<PublicDistrict,ApiError>, Result<[RouteSummary],ApiError>)
        case adminRegionPrepared(Result<Region,ApiError>,  Result<[PublicDistrict],ApiError>)
        case destination(PresentationAction<Destination.Action>)
        case alert(PresentationAction<OkAlert.Action>)
    }

    var body: some ReducerOf<AppFeature> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                state.isAWSLoading = true
                return .run { send in
                    let result = await awsCognitoClient.initialize()
                    await send(.awsInitializeReceived(result))
                }
            case .adminDistrictPrepared(let districtResult, let routesResult):
                if case let .success(district) = districtResult,
                   case let .success(routes) = routesResult{
                    state.destination = .adminDistrict(AdminDistrictFeature.State(district: district,  routes: routes.sorted()))
                }else{
                    state.alert = OkAlert.make("情報の取得に失敗しました")
                }
                state.isAdminDistrictLoading = false
                return .none
            case .adminRegionPrepared(let regionResult, let districtsResult):
                
                if case let .success(region) = regionResult,
                   case let .success(districts) = districtsResult{
                    state.destination = .adminRegion(AdminRegionFeature.State(region: region, districts: districts))
                }else{
                    state.alert = OkAlert.make("情報の取得に失敗しました")
                }
                state.isAdminRegionLoading = false
                return .none
            case .routeTapped:
                state.destination = .route(RouteFeature.State())
                return .none
            case .infoTapped:
                state.destination = .info(InfoFeature.State())
                return .none
            case .adminTapped:
                print(state.userRole)
                if case let .district(id) = state.userRole {
                    state.isAdminDistrictLoading = true
                    return adminDistrictEffect(id, accessToken: accessToken.value)
                } else if case let .region(id) = state.userRole {
                    state.isAdminRegionLoading = true
                    return adminRegionEffect(id)
                } else {
                    state.destination = .login(LoginFeature.State())
                    return .none
                }
            case .settingsTapped:
                state.destination = .settings(SettingsFeature.State())
                return .none
            case .awsInitializeReceived(.success(_)):
                state.isAWSLoading = false
                return awsUserRoleAndTokenEffect(shouldNavigate: false)
            case .awsInitializeReceived(.failure(_)):
                state.userRole = .guest
                state.isAWSLoading = false
                return .none
            case .awsUserRoleReceived(.success(let userRole),shouldNavigate: let shouldNavigate):
                state.userRole = userRole
                state.isAWSLoading = false
                if(!shouldNavigate){
                    return .none
                }
                if case let .district(id) = userRole{
                    return adminDistrictEffect(id, accessToken: accessToken.value)
                } else if case let .region(id) = userRole {
                    return adminRegionEffect(id)
                } else {
                    return .none
                }
            case .awsUserRoleReceived(.failure(_), shouldNavigate: _):
                state.userRole = .guest
                state.isAWSLoading = false
                return .none
            case .destination(.presented(let childAction)):
                switch childAction {
                case .login(.received(.success)),
                    .login(.confirmSignIn(.presented(.received(.success)))):
                    return awsUserRoleAndTokenEffect(shouldNavigate: true)
                case .login(.received(.failure(_))):
                    state.alert = OkAlert.make("ログインに失敗しました")
                    state.userRole = .guest
                    return .run { send in
                        let result = await awsCognitoClient.signOut()
                        print(result)
                    }
                case .adminDistrict(.signOutReceived(.success(_))),
                    .adminRegion(.signOutReceived(.success(_))):
                    state.destination = nil
                    state.userRole = .guest
                    accessToken.value = nil
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
            case .destination(.dismiss):
                state.destination = nil
                return .none
            case .alert(.presented(.okTapped)):
                state.alert = nil
                return .none
            case .alert(_):
                return .none
            }
        }
        .ifLet(\.$destination, action: \.destination)
        .ifLet(\.$alert, action: \.alert)
    }
    
    func adminDistrictEffect(_ id: String, accessToken: String?)-> Effect<Action> {
        .run { send in
            async let districtResult = apiClient.getDistrict(id)
            async let routesResult =  apiClient.getRoutes(id,  accessToken)
            let _ = await (districtResult, routesResult)
            await send(.adminDistrictPrepared(districtResult, routesResult))
        }
    }
    
    func adminRegionEffect(_ id: String)-> Effect<Action> {
        .run { send in
            async let regionResult = apiClient.getRegion(id)
            async let districtsResult =  apiClient.getDistricts(id)
            let _ = await (regionResult, districtsResult)
            await send(.adminRegionPrepared(regionResult, districtsResult))
        }
    }
    
    func awsUserRoleAndTokenEffect(shouldNavigate: Bool)->Effect<Action> {
        .merge(
            .run { send in
                let result = await awsCognitoClient.getTokens()
                switch result {
                case .success(let tokens):
                    if let token = tokens.accessToken?.tokenString {
                        accessToken.value = token
                    } else {
                        print("No access token found")
                    }
                case .failure(_):
                    //TODO
                    break
                }
            },
            .run { send in
                let result = await awsCognitoClient.getUserRole()
                await send(.awsUserRoleReceived(result, shouldNavigate: shouldNavigate))
            }
        )
    }
    
}

extension AppFeature.Destination.State: Equatable {}
extension AppFeature.Destination.Action: Equatable {}
