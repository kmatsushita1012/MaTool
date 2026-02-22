//
//  HomeFeature.swift
//  MaTool
//
//  Created by 松下和也 on 2025/04/20.
//

import ComposableArchitecture
import Foundation
import Shared
import SQLiteData

@Reducer
struct HomeFeature {
    
    @Reducer
    enum Destination {
        case map(PublicMapFeature)
        case info(InfoListFeature)
        case login(LoginFeature)
        case adminDistrict(DistrictDashboardFeature)
        case adminFestival(FestivalDashboardFeature)
        case settings(SettingsFeature)
    }
    
    @ObservableState
    struct State: Equatable {
        var userRole: UserRole
        var currentRouteId: Route.ID?
        var isDestinationLoading: Bool = false
        var isLoading: Bool {
            isDestinationLoading
        }
        var status: StatusCheckResult? = nil
        @Presents var destination: Destination.State?
        @Presents var alert: AlertFeature.State?
        
        init(userRole: UserRole, currentRouteId: Route.ID? = nil){
            self.userRole = userRole
            self.currentRouteId = currentRouteId
        }
    }
    

    @CasePathable
    enum Action: Equatable,BindableAction {
        case binding(BindingAction<HomeFeature.State>)
        case initialize
        case mapTapped
        case infoTapped
        case adminTapped
        case settingsTapped
        case statusReceived(StatusCheckResult?)
        case settingsPrepared(VoidTaskResult)
        case destination(PresentationAction<Destination.Action>)
        case alert(PresentationAction<AlertFeature.Action>)
    }
    
    @Dependency(\.authService) var authService
    @Dependency(UserDefaltsManagerKey.self) var userDefaults
    @Dependency(\.appStatusClient) var appStatusClient
    @Dependency(FestivalDataFetcherKey.self) var festivalDataFetcher
    
    var body: some ReducerOf<HomeFeature> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .binding:
                return .none
            case .initialize:
                return .run { send in
                    let result = await appStatusClient.checkStatus()
                    await send(.statusReceived(result))
                }
            case .statusReceived(let value):
                state.status = value
                return .none
            case .mapTapped:
                guard let festivalId = userDefaults.defaultFestivalId,
                      let festival = FetchOne(Festival.find(festivalId)).wrappedValue else{
                      state.alert = AlertFeature.error("設定画面で参加する祭典を選択してください")
                        return .none
                }
                if let districtId = userDefaults.defaultDistrictId,
                   let district = FetchOne(District.find(districtId)).wrappedValue
                {
                    state.destination = .map(.init(festival: festival, district: district, routeId: state.currentRouteId))
                    return .none
                } else {
                    state.destination = .map(.init(festival: festival))
                    return .none
                }
            case .infoTapped:
                guard let festivalId = userDefaults.defaultFestivalId,
                      let festival = FetchOne(Festival.find(festivalId)).wrappedValue else {
                    state.alert = AlertFeature.error("設定画面から祭典を選択してください。")
                    return .none
                }
                state.destination = .info(.init(festival: festival))
                return .none
            case .adminTapped:
                return adminTapped(state: &state, action: action)
            case .settingsTapped:
                state.isDestinationLoading = true
                return .task(Action.settingsPrepared) {
                    try await festivalDataFetcher.fetchAll()
                }
            case .settingsPrepared(.success):
                state.isDestinationLoading = false
                state.destination = .settings(.init())
                return .none
            case .settingsPrepared(.failure(let error)):
                state.alert = AlertFeature.error("設定画面の準備に失敗しました。\n\(error)")
                return .none
            case .destination(.presented(.settings(.districtSelectReceived(.success(let routeId))))):
                state.currentRouteId = routeId
                return .none
            case .destination(.presented(let childAction)):
                switch childAction {
                case .login(.received(.success(.signedIn(let userRole)))),
                        .login(.destination(.presented(.confirmSignIn(.received(.success(let userRole)))))):
                    state.userRole = userRole
                    switch state.userRole {
                    case .headquarter(let id):
                        return adminFestivalPrepared(state: &state, action: action, festivalId: id)
                    case .district(let id):
                        return adminDistrictPrepared(state: &state, action: action, districtId: id)
                    case .guest:
                        return .none
                    }
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
            return adminFestivalPrepared(state: &state, action: action, festivalId: id)
        case .district(let id):
            return adminDistrictPrepared(state: &state, action: action, districtId: id)
        case .guest:
            state.destination = .login(LoginFeature.State(id: ""))// FIXME
            return .none
        }
    }
    
    func adminFestivalPrepared(state: inout State, action: Action, festivalId: Festival.ID) -> Effect<Action> {
        guard  let festival = FetchOne(Festival.find(festivalId)).wrappedValue else {
            state.alert = AlertFeature.error("情報の取得に失敗しました")
            return .none
        }
        state.destination = .adminFestival(.init(festival))
        return .none
    }
    
    func adminDistrictPrepared(state: inout State, action: Action, districtId: District.ID) -> Effect<Action> {
        guard  let district = FetchOne(District.find(districtId)).wrappedValue else {
            state.alert = AlertFeature.error("情報の取得に失敗しました")
            return .none
        }
        state.destination = .adminDistrict(.init(district))
        return .none
    }
}

extension HomeFeature.Destination.State: Equatable {}
extension HomeFeature.Destination.Action: Equatable {}
