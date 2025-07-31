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
        case info(InfoList)
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
        var shouldShowUpdateModal: Bool = false
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
        case updateReceived(Bool)
        case awsInitializeReceived(Result<UserRole, AuthError>)
        case infoPrepared(Result<Region, ApiError>, Result<[PublicDistrict], ApiError>)
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
    @Dependency(\.updateManager) var updateManager
    
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
                        await updateManager.checkVersion()
                        await send(.updateReceived(updateManager.shouldShowUpdate))
                    },
                    .run { send in
                        let result = await authService.initialize()
                        await send(.awsInitializeReceived(result))
                    }
                )
            case .updateReceived(let value):
                state.shouldShowUpdateModal = value
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
                guard let regionId = userDefaultsClient.string(defaultRegionKey) else {
                    state.alert = Alert.error("設定画面から祭典を選択してください。")
                    return .none
                }
                return infoEffect(regionId: regionId)
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
            case let .infoPrepared(regionResult, districtsResult):
                switch (regionResult, districtsResult) {
                case (.success(let region), .success(let districts)):
                    if let districtId = userDefaultsClient.string(defaultRegionKey) {
                        state.destination = .info(
                            InfoList.State(
                                region: region,
                                districts: districts.prioritizing(by: \.id, match: districtId)
                            )
                        )
                    } else {
                        state.destination = .info(
                            InfoList.State(
                                region: region,
                                districts: districts
                            )
                        )
                    }
                case (_, _):
                    state.alert = Alert.error("情報の取得に失敗しました")
                }
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
            async let districtsResult: Result<[PublicDistrict], ApiError> = {
                guard let id = regionId else { return .success([]) }
                return await apiRepository.getDistricts(id)
            }()

            let regions = await regionsResult
            let districts = await districtsResult

            let region: Result<Region?, ApiError> = {
                switch regions {
                case .success(let list):
                    guard let id = regionId else { return .success(nil) }
                    return .success(list.first { $0.id == id })
                case .failure(let error):
                    return .failure(error)
                }
            }()

            let district: Result<PublicDistrict?, ApiError> = {
                switch districts {
                case .success(let list):
                    guard let id = districtId else { return .success(nil) }
                    return .success(list.first { $0.id == id })
                case .failure(let error):
                    return .failure(error)
                }
            }()

            await send(.settingsPrepared(regions, region, districts, district))
        }
    }

    func infoEffect(regionId: String) -> Effect<Action> {
        .run { send in
            async let regionResult = apiRepository.getRegion(regionId)
            async let districtsResult = apiRepository.getDistricts(regionId)
            
            let region = await regionResult
            let districts = await districtsResult
            
            await send(.infoPrepared(region, districts))
        }
    }
}

extension Home.Destination.State: Equatable {}
extension Home.Destination.Action: Equatable {}
