//
//  HomeFeature.swift
//  MaTool
//
//  Created by 松下和也 on 2025/04/20.
//

import ComposableArchitecture
import Foundation
import Shared

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
        @Shared fileprivate var appState: AppState?
        var isDestinationLoading: Bool = false
        var isLoading: Bool {
            isDestinationLoading
        }
        @Presents var destination: Destination.State?
        @Presents var alert: AlertFeature.State?
        
        var selectedFestival: Festival? {
            appState?.festivalState.festival
        }

        var districts: [District] {
            appState?.festivalState.districts ?? []
        }

        var selectedDistrict: District? {
            guard let districtId = appState?.districtState?.districtId else { return nil }
            return appState?.festivalState.districts.first { $0.id == districtId }
        }

        var performances: [Performance] {
            appState?.districtState?.performances ?? []
        }

        var routes: [Route] {
            appState?.districtState?.routes ?? []
        }

        init(userRole: UserRole, currentRouteId: Route.ID? = nil, appState: Shared<AppState?> = Shared(value: nil)){
            self.userRole = userRole
            self.currentRouteId = currentRouteId
            self._appState = appState
        }
    }
    

    @CasePathable
    enum Action: Equatable,BindableAction {
        case binding(BindingAction<HomeFeature.State>)
        case mapTapped
        case infoTapped
        case adminTapped
        case settingsTapped
        case settingsPrepared(AppResult<SettingsPreparation>)
        case loginSucceeded(UserRole)
        case loginSucceededAfterDismiss(UserRole)
        case destination(PresentationAction<Destination.Action>)
        case alert(PresentationAction<AlertFeature.Action>)
    }
    
    @Dependency(\.authService) var authService
    @Dependency(FetchFestivalListUseCaseKey.self) var fetchFestivalListUseCase
    @Dependency(GetSceneSelectionUseCaseKey.self) var getSceneSelectionUseCase
    
    var body: some ReducerOf<HomeFeature> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .binding:
                return .none
            case .mapTapped:
                guard let festival = state.selectedFestival else {
                      state.alert = AlertFeature.error("設定画面で参加する祭典を選択してください")
                        return .none
                }
                if let district = state.selectedDistrict {
                    state.destination = .map(.init(
                        festival: festival,
                        district: district,
                        routeId: state.currentRouteId,
                        userRole: state.userRole,
                        appState: state.$appState
                    ))
                } else {
                    state.destination = .map(.init(festival: festival, userRole: state.userRole, appState: state.$appState))
                }
                return .none
            case .infoTapped:
                guard let festival = state.selectedFestival else {
                    state.alert = AlertFeature.error("設定画面から祭典を選択してください。")
                    return .none
                }
                state.destination = .info(.init(festival, appState: state.$appState))
                return .none
            case .adminTapped:
                return adminTapped(state: &state, action: action)
            case .settingsTapped:
                state.isDestinationLoading = true
                return .task(Action.settingsPrepared) {
                    let festivals = try await fetchFestivalListUseCase()
                    let selection = getSceneSelectionUseCase()
                    return SettingsPreparation(festivals: festivals, selection: selection)
                }
            case .settingsPrepared(.success(let selection)):
                state.isDestinationLoading = false
                state.destination = .settings(.init(
                    selection: selection.selection,
                    festivals: selection.festivals,
                    appState: state.$appState
                ))
                return .none
            case .settingsPrepared(.failure(let error)):
                state.isDestinationLoading = false
                state.alert = AlertFeature.error("設定画面の準備に失敗しました。\n\(error)")
                return .none
            case .destination(.presented(.settings(.districtSelectReceived(.success(let routeId))))):
                state.currentRouteId = routeId
                return .none
            case .destination(.presented(.settings(.festivalSelectReceived(.success(.changed(let userRole)))))):
                // 祭変更時のみユーザーロールが返る
                state.userRole = userRole
                state.currentRouteId = nil
                return .none
            case .destination(.presented(.login(.received(.success(.signedIn(let userRole)))))),
                    .destination(.presented(.login(.confirmSignInCompleted(let userRole)))):
                state.userRole = userRole
                state.destination = nil
                switch userRole {
                case .headquarter(let id):
                    return adminFestivalPrepared(state: &state, action: action, festivalId: id)
                case .district(let id):
                    return adminDistrictPrepared(state: &state, action: action, districtId: id)
                case .guest:
                    return .none
                }
            case .destination(.presented(.info(.mapRequested(let request)))):
                switch request {
                case .locations(let festival):
                    state.destination = .map(.init(festival: festival, userRole: state.userRole, appState: state.$appState))
                    return .none
                case .route(let festival, let district, let routeId):
                    state.currentRouteId = routeId
                    state.destination = .map(.init(
                        festival: festival,
                        district: district,
                        routeId: routeId,
                        userRole: state.userRole,
                        appState: state.$appState
                    ))
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
            state.destination = .login(LoginFeature.State(id: "", appState: state.$appState))
            return .none
        }
    }
    
    func adminFestivalPrepared(state: inout State, action: Action, festivalId: Festival.ID) -> Effect<Action> {
        guard let festival = state.selectedFestival, festival.id == festivalId else {
            state.alert = AlertFeature.error("情報の取得に失敗しました")
            return .none
        }
        state.destination = .adminFestival(.init(festival, appState: state.$appState))
        return .none
    }
    
    func adminDistrictPrepared(state: inout State, action: Action, districtId: District.ID) -> Effect<Action> {
        guard let district = state.districts.first(where: { $0.id == districtId }) else {
            state.alert = AlertFeature.error("情報の取得に失敗しました")
            return .none
        }
        state.destination = .adminDistrict(.init(district, appState: state.$appState))
        return .none
    }
}

struct SettingsPreparation: Equatable {
    let festivals: [Festival]
    let selection: SceneSelection
}

extension HomeFeature.Destination.State: Equatable {}
extension HomeFeature.Destination.Action: Equatable {}
