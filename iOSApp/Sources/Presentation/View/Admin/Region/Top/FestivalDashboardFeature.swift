//
//  FestivalDashboardFeature.swift
//  MaTool
//
//  Created by 松下和也 on 2025/05/09.
//

import ComposableArchitecture
import Fallback
import Foundation
import Shared

@Reducer
struct FestivalDashboardFeature {

    @Reducer
    enum Destination {
        case edit(FestivalEditFeature)
        case districts(HeadquarterDistrictListFeature)
        case periods(PeriodListFeature)
        case changePassword(ChangePasswordFeature)
        case updateEmail(UpdateEmailFeature)
        case settings(SettingsFeature)
    }

    @ObservableState
    struct State: Equatable {
        @Shared fileprivate var appState: AppState?

        @Fallback(\FestivalDashboardFeature.State.appState?.festivalState.festival)
        @ObservationStateIgnored
        var festival: Festival

        var isApiLoading: Bool = false
        var isAuthLoading: Bool = false
        var isExportLoading: Bool = false
        var isSettingsLoading: Bool = false

        @Presents var destination: Destination.State? = nil
        @Presents var alert: AlertFeature.State? = nil
        var isLoading: Bool {
            isApiLoading || isAuthLoading || isExportLoading || isSettingsLoading
        }

        init(_ festival: Festival, appState: Shared<AppState?>) {
            self._appState = appState
            self._festival = festival
        }
    }

    @CasePathable
    enum Action: Equatable, BindableAction {
        case binding(BindingAction<State>)
        case onEdit
        case periodTapped
        case districtsTapped
        case dismissTapped
        case changePasswordTapped
        case updateEmailTapped
        case settingsTapped
        case settingsPrepared(AppResult<SettingsPreparation>)
        case signOutTapped
        case signOutReceived(VoidAppResult)
        case periodsPrepared(AppResult<[Period]>)
        case destination(PresentationAction<Destination.Action>)
        case alert(PresentationAction<AlertFeature.Action>)
    }

    @Dependency(FetchFestivalPeriodsUseCaseKey.self) var fetchFestivalPeriodsUseCase
    @Dependency(SignOutUseCaseKey.self) var signOutUseCase
    @Dependency(FetchFestivalListUseCaseKey.self) var fetchFestivalListUseCase
    @Dependency(GetSceneSelectionUseCaseKey.self) var getSceneSelectionUseCase
    @Dependency(\.dismiss) var dismiss

    var body: some ReducerOf<FestivalDashboardFeature> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .onEdit:
                state.destination = .edit(FestivalEditFeature.State(state.festival, appState: state.$appState))
                return .none
            case .periodTapped:
                state.isApiLoading = true
                let festivalId = state.festival.id
                return .task(Action.periodsPrepared) {
                    try await fetchFestivalPeriodsUseCase(festivalId: festivalId)
                }
            case .periodsPrepared(.success(let periods)):
                state.isApiLoading = false
                state.destination = .periods(PeriodListFeature.State(
                    festivalId: state.festival.id,
                    periods: periods,
                    appState: state.$appState
                ))
                return .none
            case .periodsPrepared(.failure(let error)):
                state.isApiLoading = false
                state.alert = AlertFeature.error("日程の取得に失敗しました。\n\(error.message)")
                return .none
            case .districtsTapped:
                state.destination = .districts(.init(state.festival, appState: state.$appState))
                return .none
            case .dismissTapped:
                return .dismiss
            case .changePasswordTapped:
                state.destination = .changePassword(ChangePasswordFeature.State())
                return .none
            case .updateEmailTapped:
                state.destination = .updateEmail(UpdateEmailFeature.State())
                return .none
            case .settingsTapped:
                state.isSettingsLoading = true
                return .task(Action.settingsPrepared) {
                    let festivals = try await fetchFestivalListUseCase()
                    let selection = getSceneSelectionUseCase()
                    return SettingsPreparation(festivals: festivals, selection: selection)
                }
            case .settingsPrepared(.success(let preparation)):
                state.isSettingsLoading = false
                state.destination = .settings(.init(
                    selection: preparation.selection,
                    festivals: preparation.festivals,
                    userRole: .headquarter(state.festival.id),
                    appState: state.$appState
                ))
                return .none
            case .settingsPrepared(.failure(let error)):
                state.isSettingsLoading = false
                state.alert = AlertFeature.error("設定画面の準備に失敗しました。\n\(error.message)")
                return .none
            case .signOutTapped:
                state.isAuthLoading = true
                return .task(Action.signOutReceived) {
                    try await signOutUseCase()
                }
                .cancellable(id: SceneSessionCancellationID.active, cancelInFlight: true)
            case .signOutReceived(.failure(let error)):
                state.isAuthLoading = false
                state.alert = AlertFeature.error("ログアウトに失敗しました　\(error.message)")
                return .none
            case .signOutReceived(.success):
                state.isAuthLoading = false
                return .none
            case .destination(.presented(.edit(.putReceived(.success)))):
                state.destination = nil
                return .none
            case .destination(.presented(.changePassword(.received(.success)))):
                state.destination = nil
                state.alert = AlertFeature.success("パスワードが変更されました")
                return .none
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
}

extension FestivalDashboardFeature.Destination.State: Equatable {}
extension FestivalDashboardFeature.Destination.Action: Equatable {}
