//
//  Home.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/04/20.
//

import AWSMobileClient
import ComposableArchitecture
import Foundation

@Reducer
struct Home {
    
    @Reducer
    enum Destination {
        case route(PublicMap)
        case info(Info)
        case login(Login)
        case adminDistrict(AdminDistrictTop)
        case adminRegion(AdminRegionTop)
        case settings(Settings)
    }
    
    @ObservableState
    struct State: Equatable {
        var userRole: UserRole = .guest
        var isAuthLoading: Bool = true
        var isDestinationLoading: Bool = false
        var isLoading: Bool {
            isDestinationLoading
        }
        var status: StatusCheckResult? = nil
        @Presents var destination: Destination.State?
        @Presents var alert: Alert.State?
    }
    

    @CasePathable
    enum Action: Equatable,BindableAction {
        case binding(BindingAction<Home.State>)
        case onAppear
        case mapTapped
        case infoTapped
        case adminTapped
        case settingsTapped
        case statusReceived(StatusCheckResult?)
        case awsInitializeReceived(Result<UserRole, AuthError>)
        case adminDistrictPrepared(Result<PublicDistrict,ApiError>, Result<[RouteSummary],ApiError>)
        case adminRegionPrepared(Result<Region,ApiError>, Result<[PublicDistrict],ApiError>)
        case settingsPrepared(
            Result<[Region],ApiError>,
            Result<Region?,ApiError>,
            Result<[PublicDistrict],ApiError>,
            Result<PublicDistrict?,ApiError>
        )
        case destination(PresentationAction<Destination.Action>)
        case alert(PresentationAction<Alert.Action>)
    }
    
    @Dependency(\.apiRepository) var apiRepository
    @Dependency(\.authService) var authService
    @Dependency(\.userDefaultsClient) var userDefaultsClient
    @Dependency(\.appStatusClient) var appStatusClient
    
    var body: some ReducerOf<Home> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .binding:
                return .none
            case .onAppear:
                state.isAuthLoading = true
                return .merge(
                    .run { send in
                        let result = await appStatusClient.checkStatus()
                        await send(.statusReceived(result))
                    },
                    .run { send in
                        let result = await authService.initialize()
                        await send(.awsInitializeReceived(result))
                    }
                )
            case .statusReceived(let value):
                state.status = value
                return .none
            case .adminDistrictPrepared(let districtResult, let routesResult):
                if case let .success(district) = districtResult,
                   case let .success(routes) = routesResult{
                    state.destination = .adminDistrict(AdminDistrictTop.State(district: district,  routes: routes.sorted()))
                }else{
                    state.alert = Alert.error("情報の取得に失敗しました")
                }
                state.isDestinationLoading = false
                return .none
            case .adminRegionPrepared(let regionResult, let districtsResult):
                if case let .success(region) = regionResult,
                   case let .success(districts) = districtsResult{
                    state.destination = .adminRegion(AdminRegionTop.State(region: region, districts: districts))
                }else{
                    state.alert = Alert.error("情報の取得に失敗しました")
                }
                state.isDestinationLoading = false
                return .none
            case .mapTapped:
                state.destination = .route(PublicMap.State())
                return .none
            case .infoTapped:
                state.destination = .info(Info.State())
                return .none
            case .adminTapped:
                if state.isAuthLoading {
                    state.alert = Alert.error("認証中です。もう一度お試しください。再度このエラーが出る場合は設定画面から強制ログアウトをお試しください。")
                    return .none
                }
                switch state.userRole {
                case .region(let id):
                    state.isDestinationLoading = true
                    return adminRegionEffect(id)
                case .district(let id):
                    state.isDestinationLoading = true
                    return adminDistrictEffect(id)
                case .guest:
                    let id = userDefaultsClient.string(loginIdKey) ?? ""
                    state.destination = .login(Login.State(id: id))
                    return .none
                }
            case .settingsTapped:
                state.isDestinationLoading = true
                let regionId = userDefaultsClient.string(defaultRegionKey)
                let districtId = userDefaultsClient.string(defaultDistrictKey)
                return settingsEffect(regionId: regionId, districtId: districtId)
            case .awsInitializeReceived(.success(let userRole)):
                state.userRole = userRole
                state.isAuthLoading = false
                return .none
            case .awsInitializeReceived(.failure(_)):
                state.isAuthLoading = false
                return .none
            case let .settingsPrepared(regionsResult, regionResult, districtsResult, districtResult):
                state.isDestinationLoading = false
                state.destination = .settings(
                    Settings.State(
                        isOfflineMode: regionsResult.value == nil,
                        regions: regionsResult.value ?? [],
                        selectedRegion: regionResult.value ?? nil,
                        districts: districtsResult.value ?? [],
                        selectedDistrict: districtResult.value ?? nil
                    )
                )
                return .none
            case .destination(.presented(let childAction)):
                switch childAction {
                case .login(.received(.success(let userRole))),
                    .login(.destination(.presented(.confirmSignIn(.received(.success(let userRole)))))):
                    state.userRole = userRole
                    state.destination = nil
                    switch state.userRole {
                    case .region(let id):
                        state.isDestinationLoading = true
                        return adminRegionEffect(id)
                    case .district(let id):
                        state.isDestinationLoading = true
                        return adminDistrictEffect(id)
                    case .guest:
                        return .none
                    }
                case .login(.received(.failure(_))):
                    return .none
                case .adminDistrict(.signOutReceived(.success(let userRole))),
                    .adminRegion(.signOutReceived(.success(let userRole))):
                    state.userRole = userRole
                    state.destination = nil
                    return .none
                case .settings(.signOutReceived(.success(let userRole))):
                    state.userRole = userRole
                    return .none
                default:
                    return .none
                }
            case .destination(.dismiss):
                return .none
            case .alert:
                state.alert = nil
                return .none
            }
        }
        .ifLet(\.$destination, action: \.destination)
        .ifLet(\.$alert, action: \.alert)
    }
    
    func adminDistrictEffect(_ id: String)-> Effect<Action> {
        .run { send in
            guard let accessToken = await authService.getAccessToken() else { return }
            async let districtResult = apiRepository.getDistrict(id)
            async let routesResult =  apiRepository.getRoutes(id,  accessToken)
            let _ = await (districtResult, routesResult)
            await send(.adminDistrictPrepared(districtResult, routesResult))
        }
    }
    
    func adminRegionEffect(_ id: String)-> Effect<Action> {
        .run { send in
            async let regionResult = apiRepository.getRegion(id)
            async let districtsResult =  apiRepository.getDistricts(id)
            let _ = await (regionResult, districtsResult)
            await send(.adminRegionPrepared(regionResult, districtsResult))
        }
    }
    
    func settingsEffect(regionId: String?, districtId: String?) -> Effect<Action> {
        .run { send in
            async let regionsResult = apiRepository.getRegions()

            async let regionResult: Result<Region?, ApiError> = {
                guard let id = regionId else { return .success(nil) }
                return await apiRepository.getRegion(id).map { Optional($0) }
            }()
            async let districtsResult: Result<[PublicDistrict], ApiError> = {
                guard let id = regionId else { return .success([]) }
                return await apiRepository.getDistricts(id)
            }()
            async let districtResult: Result<PublicDistrict?, ApiError> = {
                guard let id = districtId else { return .success(nil) }
                return await apiRepository.getDistrict(id).map { Optional($0) }
            }()

            let regions = await regionsResult
            let region = await regionResult
            let districts = await districtsResult
            let district = await districtResult
            
            await send(.settingsPrepared(regions, region, districts, district))
        }
    }
    
}

extension Home.Destination.State: Equatable {}
extension Home.Destination.Action: Equatable {}
