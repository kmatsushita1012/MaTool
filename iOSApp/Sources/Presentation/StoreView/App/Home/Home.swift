//
//  Home.swift
//  MaTool
//
//  Created by 松下和也 on 2025/04/20.
//

import ComposableArchitecture
import Foundation
import Shared
import SQLiteData

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
        case adminDistrictPrepared(VoidResult<APIError>)
        case adminFestivalPrepared(VoidResult<APIError>)
        
        case settingsPrepared
        case destination(PresentationAction<Destination.Action>)
        case alert(PresentationAction<Alert.Action>)
    }
    
    @Dependency(\.authService) var authService
    @Dependency(\.userDefaultsClient) var userDefaultsClient
    @Dependency(\.appStatusClient) var appStatusClient
    @Dependency(\.values.defaultFestivalKey) var defaultFestivalKey
    @Dependency(\.values.defaultDistrictKey) var defaultDistrictKey
    @Dependency(\.values.loginIdKey) var loginIdKey
    @Dependency(FestivalDataFetcherKey.self) var festivalDataFetcher
    
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
                    state.destination = .map(.init(festival: <#T##Festival#>, district: <#T##District#>, routeId: <#T##Route.ID#>))
                    return .none// FIXME:
                } else if let festivalId {
                    state.isDestinationLoading = true
                    return .none// FIXME:
                }
                state.alert = Alert.error("設定画面で参加する祭典を選択してください")
                return .none
            case .infoTapped:
                guard let festivalId = userDefaultsClient.string(defaultFestivalKey) else {
                    state.alert = Alert.error("設定画面から祭典を選択してください。")
                    return .none
                }
                state.isDestinationLoading = true
                return .none //FIXME
            case .adminTapped:
                return adminTapped(state: &state, action: action)
            case .settingsTapped:
                state.isDestinationLoading = true
                let festivalId = userDefaultsClient.string(defaultFestivalKey)
                let districtId = userDefaultsClient.string(defaultDistrictKey)
                return .run {send in 
                    let result = await task{ try await festivalDataFetcher.fetchAll()}
                    //FIXME:
                }
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
            case .destination(.presented(let childAction)):
                switch childAction {
                case .login(.received(.success(let userRole))),
                        .login(.destination(.presented(.confirmSignIn(.received(.success(let userRole)))))):
                    state.userRole = userRole
                    switch state.userRole {
                    case .headquarter(let id):
                        state.isDestinationLoading = true
                        return .none
                    case .district(let id):
                        state.isDestinationLoading = true
                        return .none
                    case .guest:
                        return .none
                    }
                case .login(.received(.failure(_))):
                    return .none
                case .info(.destination(.presented(.district(.mapTapped)))):
                    guard let districtId = state.destination?.info?.destination?.district?.district.id,
                        let festivalId = userDefaultsClient.string(defaultFestivalKey)  else {
                        return .none
                    }
                    if #available(iOS 17, *) {
                        return .none
                    }else{
                        state.isDestinationLoading = true
                        state.destination = nil
                        return .none // FIXME:
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
            case .alert:
                state.alert = nil
                return .none
            default:
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
            return .none // FIXME:
        case .district(let id):
            state.isDestinationLoading = true
            return .none // FIXME:
        case .guest:
            let id = userDefaultsClient.string(loginIdKey) ?? ""
            state.destination = .login(Login.State(id: id))
            return .none
        }
    }
}

extension Home.Destination.State: Equatable {}
extension Home.Destination.Action: Equatable {}
