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
        var currentRouteId: Route.ID?
        var isDestinationLoading: Bool = false
        var isLoading: Bool {
            isDestinationLoading
        }
        var status: StatusCheckResult? = nil
        @Presents var destination: Destination.State?
        @Presents var alert: Alert.State?
        
        init(currentRouteId: Route.ID? = nil){
            self.currentRouteId = currentRouteId
        }
    }
    

    @CasePathable
    enum Action: Equatable,BindableAction {
        case binding(BindingAction<Home.State>)
        case initialize
        case mapTapped
        case infoTapped
        case adminTapped
        case settingsTapped
        case statusReceived(StatusCheckResult?)
        case adminDistrictPrepared(VoidResult<APIError>)
        case adminFestivalPrepared(VoidResult<APIError>)
        
        case settingsPrepared
        case destination(PresentationAction<Destination.Action>)
        case alert(PresentationAction<Alert.Action>)
    }
    
    @Dependency(\.authService) var authService
    @Dependency(UserDefaltsManagerKey.self) var userDefaults
    @Dependency(\.appStatusClient) var appStatusClient
    @Dependency(FestivalDataFetcherKey.self) var festivalDataFetcher
    
    var body: some ReducerOf<Home> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .binding:
                return .none
            case .initialize:
                return .merge(
                    .run { send in
                        let result = await appStatusClient.checkStatus()
                        await send(.statusReceived(result))
                    },
                )
            case .statusReceived(let value):
                state.status = value
                return .none
            case .mapTapped:
                guard let festivalId = userDefaults.defaultFestivalId,
                      let festival = FetchOne(Festival.find(festivalId)).wrappedValue else{
                      state.alert = Alert.error("設定画面で参加する祭典を選択してください")
                        return .none
                }
                if let districtId = userDefaults.defaultDistrictId,
                   let district = FetchOne(District.find(districtId)).wrappedValue
                {
                    state.isDestinationLoading = true
                    state.destination = .map(.init(festival: festival, district: district, routeId: state.currentRouteId))
                    return .none// FIXME:
                } else {
                    state.isDestinationLoading = true
                    state.destination = .map(.init(festival: festival))
                    return .none// FIXME:
                }
                
            case .infoTapped:
                guard let festivalId = userDefaults.defaultFestivalId,
                      let festival = FetchOne(Festival.find(festivalId)).wrappedValue else {
                    state.alert = Alert.error("設定画面から祭典を選択してください。")
                    return .none
                }
                state.destination = .info(.init(festival: festival))
                return .none //FIXME
            case .adminTapped:
                return adminTapped(state: &state, action: action)
            case .settingsTapped:
                state.isDestinationLoading = true
                return .run {send in 
                    let result = await task{ try await festivalDataFetcher.fetchAll()}
                    //FIXME:
                }
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
                    guard let districtId = state.destination?.info?.destination?.district?.district.id else {
                        return .none
                    }
                    if #available(iOS 17, *) {
                        return .none // FIXME:
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
        switch state.userRole {
        case .headquarter(let id):
            state.isDestinationLoading = true
            return .none // FIXME:
        case .district(let id):
            state.isDestinationLoading = true
            return .none // FIXME:
        case .guest:
            state.destination = .login(Login.State(id: ""))
            return .none
        }
    }
}

extension Home.Destination.State: Equatable {}
extension Home.Destination.Action: Equatable {}
