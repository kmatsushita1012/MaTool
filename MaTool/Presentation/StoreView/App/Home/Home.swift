//
//  Home.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/04/20.
//

import ComposableArchitecture
import Foundation

@Reducer
struct Home {
    
    @Reducer
    enum Destination {
        case map(PublicMap)
        case info(InfoList)
        case login(Login)
        case adminDistrict(AdminDistrictTop)
        case adminRegion(AdminRegionTop)
        case settings(Settings)
    }
    
    @ObservableState
    struct State: Equatable {
        var userRole: UserRole = .guest
        var isAuthLoading: Bool = false
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
        case initialize
        case mapTapped
        case infoTapped
        case adminTapped
        case settingsTapped
        case skipTapped
        case statusReceived(StatusCheckResult?)
        case awsInitializeReceived(Result<UserRole, AuthError>)
        case routePrepared(
            regionResult: Result<Region, APIError>,
            districtsResult: Result<[PublicDistrict], APIError>,
            currentResult: Result<CurrentResponse, APIError>
        )
        case locationsPrepared(
            regionResult: Result<Region, APIError>,
            districtsResult: Result<[PublicDistrict], APIError>,
            locationsResult: Result<[LocationInfo], APIError>
        )
        case infoPrepared(Result<Region, APIError>, Result<[PublicDistrict], APIError>)
        case adminDistrictPrepared(Result<PublicDistrict,APIError>, Result<[RouteSummary],APIError>)
        case adminRegionPrepared(Result<Region,APIError>, Result<[PublicDistrict],APIError>)
        
        case settingsPrepared(
            Result<[Region],APIError>,
            Result<Region?,APIError>,
            Result<[PublicDistrict],APIError>,
            Result<PublicDistrict?,APIError>
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
            case .initialize:
                state.isAuthLoading = true
                return .merge(
                    .run { send in
                        let result = await appStatusClient.checkStatus()
                        await send(.statusReceived(result))
                    },
                    .run { send in
                        let result = await authService.getUserRole()
                        await send(.awsInitializeReceived(result))
                    }
                    .cancellable(id: "AuthInitialize")
                )
            case .statusReceived(let value):
                state.status = value
                return .none
            case .mapTapped:
                let regionId = userDefaultsClient.string(defaultRegionKey)
                let districtId = userDefaultsClient.string(defaultDistrictKey)
                
                if let regionId, let districtId {
                    state.isDestinationLoading = true
                    return routeEffect(regionId: regionId, districtId: districtId)
                } else if let regionId {
                    state.isDestinationLoading = true
                    return locationsEffect(regionId)
                }
                state.alert = Alert.error("設定画面で参加する祭典を選択してください")
                return .none
            case .infoTapped:
                guard let regionId = userDefaultsClient.string(defaultRegionKey) else {
                    state.alert = Alert.error("設定画面から祭典を選択してください。")
                    return .none
                }
                state.isDestinationLoading = true
                return infoEffect(regionId: regionId)
            case .adminTapped:
                return adminTapped(state: &state, action: action)
            case .settingsTapped:
                state.isDestinationLoading = true
                let regionId = userDefaultsClient.string(defaultRegionKey)
                let districtId = userDefaultsClient.string(defaultDistrictKey)
                return settingsEffect(regionId: regionId, districtId: districtId)
            case .skipTapped:
                state.isAuthLoading = false
                let effect = adminTapped(state: &state, action: action)
                return .merge(
                    .cancel(id: "AuthInitialize"),
                    effect
                )
            case .awsInitializeReceived(.success(let userRole)):
                state.userRole = userRole
                state.isAuthLoading = false
                return .none
            case .awsInitializeReceived(.failure(_)):
                state.isAuthLoading = false
                return .none
            case .routePrepared(
                let regionResult,
                let districtsResult,
                let currentResult,
            ):
                state.isDestinationLoading = false
                switch (
                    regionResult,
                    districtsResult,
                    currentResult,
                ){
                case (.success(let region), .success(let districts), .success(let currentResponse)):
                    state.destination = .map(
                        PublicMap.State(
                            region: region,
                            districts: districts,
                            id: currentResponse.districtId,
                            routes: currentResponse.routes,
                            current: currentResponse.current,
                            location: currentResponse.location
                        )
                    )
                    return .none
                case (.success(let region), .success(let districts), .failure(let error)):
                    guard let id = userDefaultsClient.string(defaultDistrictKey) else {
                        state.alert = Alert.error("情報の取得に失敗しました \(error.localizedDescription)")
                        return .none
                    }
                    state.destination = .map(
                        PublicMap.State(
                            region: region,
                            districts: districts,
                            id: id,
                            routes: nil,
                            current: nil,
                            location: nil
                        )
                    )
                case (.failure(let error), _, _),
                    (_, .failure(let error), _):
                    state.alert = Alert.error("情報の取得に失敗しました \(error.localizedDescription)")
                }
                return .none
            case .locationsPrepared(
                let regionResult,
                let districtsResult,
                let locationsResult
            ):
                state.isDestinationLoading = false
                switch (
                    regionResult,
                    districtsResult,
                    locationsResult
                ){
                case (.success(let region), .success(let districts), .success(let locations)):
                    state.destination = .map(
                        PublicMap.State(
                            region: region,
                            districts: districts,
                            locations: locations
                        )
                    )
                case (.success(let region),
                    .success(let districts),
                      .failure(.forbidden(message: _))):
                    state.destination = .map(
                        PublicMap.State(
                            region: region,
                            districts: districts,
                            locations: []
                        )
                    )
                case (.failure(let error), _, _),
                    (_, .failure(let error), _),
                    (_, _, .failure(let error)):
                    state.alert = Alert.error("情報の取得に失敗しました \(error.localizedDescription)")
                }
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
            case let .infoPrepared(regionResult, districtsResult):
                state.isDestinationLoading = false
                switch (regionResult, districtsResult) {
                case (.success(let region), .success(let districts)):
                    if let districtId = userDefaultsClient.string(defaultDistrictKey) {
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
                case .info(.destination(.presented(.district(.mapTapped)))):
                    guard let districtId = state.destination?.info?.destination?.district?.item.id,
                        let regionId = userDefaultsClient.string(defaultRegionKey)  else {
                        return .none
                    }
                    if #available(iOS 17, *) {
                        return routeEffect(regionId: regionId, districtId: districtId)
                    }else{
                        state.isDestinationLoading = true
                        state.destination = nil
                        return routeEffect(regionId: regionId, districtId: districtId)
                    }
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
    
    func adminTapped(state: inout State, action: Action) -> Effect<Action> {
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
    }
    
    func routeEffect(regionId: String, districtId id: String) -> Effect<Action> {
        .run { send in
            async let regionTask = apiRepository.getRegion(regionId)
            async let districtsTask = apiRepository.getDistricts(regionId)
            async let currentTask = apiRepository.getCurrentRoute(id)
            
            let (
                regionResult,
                districtsResult,
                currentResult,
            ) = await (
                regionTask,
                districtsTask,
                currentTask,
            )
            
            await send(
                .routePrepared(
                    regionResult: regionResult,
                    districtsResult: districtsResult,
                    currentResult: currentResult,
                )
            )
        }
    }
    
    
    func locationsEffect(_ id: String) -> Effect<Action> {
        .run { send in
            
            async let regionTask = apiRepository.getRegion(id)
            async let districtsTask = apiRepository.getDistricts(id)
            async let locationsTask = apiRepository.getLocations(id)
            
            let (
                regionResult,
                districtsResult,
                locationsResult
            ) = await (
                regionTask,
                districtsTask,
                locationsTask
            )
            
            await send(.locationsPrepared(
                regionResult: regionResult,
                districtsResult: districtsResult,
                locationsResult: locationsResult
            ))
        }
    }
    
    func adminDistrictEffect(_ id: String)-> Effect<Action> {
        .run { send in
            async let districtResult = apiRepository.getDistrict(id)
            async let routesResult =  apiRepository.getRoutes(id)
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
            async let districtsResult: Result<[PublicDistrict], APIError> = {
                guard let id = regionId else { return .success([]) }
                return await apiRepository.getDistricts(id)
            }()

            let regions = await regionsResult
            let districts = await districtsResult

            let region: Result<Region?, APIError> = {
                switch regions {
                case .success(let list):
                    guard let id = regionId else { return .success(nil) }
                    return .success(list.first { $0.id == id })
                case .failure(let error):
                    return .failure(error)
                }
            }()

            let district: Result<PublicDistrict?, APIError> = {
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
