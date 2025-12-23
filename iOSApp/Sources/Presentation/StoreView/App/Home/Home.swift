//
//  Home.swift
//  MaTool
//
//  Created by 松下和也 on 2025/04/20.
//

import ComposableArchitecture
import Foundation
import Shared

@Reducer
struct Home {
    
    @Reducer
    enum Destination {
        case map(PublicMap)
        case info(InfoList)
        case login(Login)
        case adminDistrict(AdminDistrictTop)
        case adminFestival(FestivalDashboardFeature)
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
            festivalResult: Result<Festival, APIError>,
            districtsResult: Result<[District], APIError>,
            currentResult: Result<CurrentResponse, APIError>
        )
        case locationsPrepared(
            festivalResult: Result<Festival, APIError>,
            districtsResult: Result<[District], APIError>,
            locationsResult: Result<[FloatLocationGetDTO], APIError>
        )
        case infoPrepared(Result<Festival, APIError>, Result<[District], APIError>)
        case adminDistrictPrepared(Result<District,APIError>, Result<[RouteItem],APIError>)
        case adminFestivalPrepared(Result<Festival,APIError>, Result<[District],APIError>)
        
        case settingsPrepared(
            Result<[Festival],APIError>,
            Result<Festival?,APIError>,
            Result<[District],APIError>,
            Result<District?,APIError>
        )
        case destination(PresentationAction<Destination.Action>)
        case alert(PresentationAction<Alert.Action>)
    }
    
    @Dependency(\.apiRepository) var apiRepository
    @Dependency(\.authService) var authService
    @Dependency(\.userDefaultsClient) var userDefaultsClient
    @Dependency(\.appStatusClient) var appStatusClient
    @Dependency(\.values.defaultFestivalKey) var defaultFestivalKey
    @Dependency(\.values.defaultDistrictKey) var defaultDistrictKey
    @Dependency(\.values.loginIdKey) var loginIdKey
    
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
                let festivalId = userDefaultsClient.string(defaultFestivalKey)
                let districtId = userDefaultsClient.string(defaultDistrictKey)
                
                if let festivalId, let districtId {
                    state.isDestinationLoading = true
                    return routeEffect(festivalId: festivalId, districtId: districtId)
                } else if let festivalId {
                    state.isDestinationLoading = true
                    return locationsEffect(festivalId)
                }
                state.alert = Alert.error("設定画面で参加する祭典を選択してください")
                return .none
            case .infoTapped:
                guard let festivalId = userDefaultsClient.string(defaultFestivalKey) else {
                    state.alert = Alert.error("設定画面から祭典を選択してください。")
                    return .none
                }
                state.isDestinationLoading = true
                return infoEffect(festivalId: festivalId)
            case .adminTapped:
                return adminTapped(state: &state, action: action)
            case .settingsTapped:
                state.isDestinationLoading = true
                let festivalId = userDefaultsClient.string(defaultFestivalKey)
                let districtId = userDefaultsClient.string(defaultDistrictKey)
                return settingsEffect(festivalId: festivalId, districtId: districtId)
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
                let festivalResult,
                let districtsResult,
                let currentResult,
            ):
                state.isDestinationLoading = false
                switch (
                    festivalResult,
                    districtsResult,
                    currentResult,
                ){
                case (.success(let festival), .success(let districts), .success(let currentResponse)):
                    state.destination = .map(
                        PublicMap.State(
                            festival: festival,
                            districts: districts,
                            id: currentResponse.districtId,
                            routes: currentResponse.routes,
                            current: currentResponse.current,
                            location: currentResponse.location
                        )
                    )
                    return .none
                case (.success(let festival), .success(let districts), .failure(let error)):
                    guard let id = userDefaultsClient.string(defaultDistrictKey) else {
                        state.alert = Alert.error("情報の取得に失敗しました \(error.localizedDescription)")
                        return .none
                    }
                    state.destination = .map(
                        PublicMap.State(
                            festival: festival,
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
                let festivalResult,
                let districtsResult,
                let locationsResult
            ):
                state.isDestinationLoading = false
                switch (
                    festivalResult,
                    districtsResult,
                    locationsResult
                ){
                case (.success(let festival), .success(let districts), .success(let locations)):
                    state.destination = .map(
                        PublicMap.State(
                            festival: festival,
                            districts: districts,
                            locations: locations
                        )
                    )
                case (.success(let festival),
                    .success(let districts),
                      .failure(.forbidden(message: _))):
                    state.destination = .map(
                        PublicMap.State(
                            festival: festival,
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
            case .adminFestivalPrepared(let festivalResult, let districtsResult):
                if case let .success(festival) = festivalResult,
                   case let .success(districts) = districtsResult{
                    state.destination = .adminFestival(FestivalDashboardFeature.State(festival: festival, districts: districts))
                }else{
                    state.alert = Alert.error("情報の取得に失敗しました")
                }
                state.isDestinationLoading = false
                return .none
            case let .infoPrepared(festivalResult, districtsResult):
                state.isDestinationLoading = false
                switch (festivalResult, districtsResult) {
                case (.success(let festival), .success(let districts)):
                    if let districtId = userDefaultsClient.string(defaultDistrictKey) {
                        state.destination = .info(
                            InfoList.State(
                                festival: festival,
                                districts: districts.prioritizing(by: \.id, match: districtId)
                            )
                        )
                    } else {
                        state.destination = .info(
                            InfoList.State(
                                festival: festival,
                                districts: districts
                            )
                        )
                    }
                case (_, _):
                    state.alert = Alert.error("情報の取得に失敗しました")
                }
                return .none
            case let .settingsPrepared(festivalsResult, festivalResult, districtsResult, districtResult):
                state.isDestinationLoading = false
                state.destination = .settings(
                    Settings.State(
                        isOfflineMode: festivalsResult.value == nil,
                        festivals: festivalsResult.value ?? [],
                        selectedFestival: festivalResult.value ?? nil,
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
                    case .headquarter(let id):
                        state.isDestinationLoading = true
                        return adminFestivalEffect(id)
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
                        let festivalId = userDefaultsClient.string(defaultFestivalKey)  else {
                        return .none
                    }
                    if #available(iOS 17, *) {
                        return routeEffect(festivalId: festivalId, districtId: districtId)
                    }else{
                        state.isDestinationLoading = true
                        state.destination = nil
                        return routeEffect(festivalId: festivalId, districtId: districtId)
                    }
                case .adminDistrict(.signOutReceived(.success(let userRole))),
                    .adminFestival(.signOutReceived(.success(let userRole))):
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
        case .headquarter(let id):
            state.isDestinationLoading = true
            return adminFestivalEffect(id)
        case .district(let id):
            state.isDestinationLoading = true
            return adminDistrictEffect(id)
        case .guest:
            let id = userDefaultsClient.string(loginIdKey) ?? ""
            state.destination = .login(Login.State(id: id))
            return .none
        }
    }
    
    func routeEffect(festivalId: String, districtId id: String) -> Effect<Action> {
        .run { send in
            async let festivalTask = apiRepository.getFestival(festivalId)
            async let districtsTask = apiRepository.getDistricts(festivalId)
            async let currentTask = apiRepository.getCurrentRoute(id)
            
            let (
                festivalResult,
                districtsResult,
                currentResult,
            ) = await (
                festivalTask,
                districtsTask,
                currentTask,
            )
            
            await send(
                .routePrepared(
                    festivalResult: festivalResult,
                    districtsResult: districtsResult,
                    currentResult: currentResult,
                )
            )
        }
    }
    
    
    func locationsEffect(_ id: String) -> Effect<Action> {
        .run { send in
            
            async let festivalTask = apiRepository.getFestival(id)
            async let districtsTask = apiRepository.getDistricts(id)
            async let locationsTask = apiRepository.getLocations(id)
            
            let (
                festivalResult,
                districtsResult,
                locationsResult
            ) = await (
                festivalTask,
                districtsTask,
                locationsTask
            )
            
            await send(.locationsPrepared(
                festivalResult: festivalResult,
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
    
    func adminFestivalEffect(_ id: String)-> Effect<Action> {
        .run { send in
            async let festivalResult = apiRepository.getFestival(id)
            async let districtsResult =  apiRepository.getDistricts(id)
            let _ = await (festivalResult, districtsResult)
            await send(.adminFestivalPrepared(festivalResult, districtsResult))
        }
    }
    
    func settingsEffect(festivalId: String?, districtId: String?) -> Effect<Action> {
        .run { send in
            async let festivalsResult = apiRepository.getFestivals()
            async let districtsResult: Result<[District], APIError> = {
                guard let id = festivalId else { return .success([]) }
                return await apiRepository.getDistricts(id)
            }()

            let festivals = await festivalsResult
            let districts = await districtsResult

            let festival: Result<Festival?, APIError> = {
                switch festivals {
                case .success(let list):
                    guard let id = festivalId else { return .success(nil) }
                    return .success(list.first { $0.id == id })
                case .failure(let error):
                    return .failure(error)
                }
            }()

            let district: Result<District?, APIError> = {
                switch districts {
                case .success(let list):
                    guard let id = districtId else { return .success(nil) }
                    return .success(list.first { $0.id == id })
                case .failure(let error):
                    return .failure(error)
                }
            }()

            await send(.settingsPrepared(festivals, festival, districts, district))
        }
    }

    func infoEffect(festivalId: String) -> Effect<Action> {
        .run { send in
            async let festivalResult = apiRepository.getFestival(festivalId)
            async let districtsResult = apiRepository.getDistricts(festivalId)
            
            let festival = await festivalResult
            let districts = await districtsResult
            
            await send(.infoPrepared(festival, districts))
        }
    }
}

extension Home.Destination.State: Equatable {}
extension Home.Destination.Action: Equatable {}
