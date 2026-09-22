import iOSShared
import Application
import View
//
//  FestivalDashboardFeature.swift
//  MaTool
//
//  Created by 松下和也 on 2025/05/09.
//

import ComposableArchitecture
import Foundation
import SQLiteData
import Shared

@Reducer
struct FestivalDashboardFeature {

    @Reducer
    enum Destination {
        case districts(HeadquarterDistrictListFeature)
        case periods(PeriodListFeature)
        case changePassword(ChangePasswordFeature)
        case updateEmail(UpdateEmailFeature)
    }

    @Reducer
    enum EditDestination {
        case festival(FestivalEditFeature)
    }

    @ObservableState
    struct State: Equatable {
        @FetchOne var festival: Festival

        var isApiLoading: Bool = false
        var isAuthLoading: Bool = false
        var isExportLoading: Bool = false

        @Presents var destination: Destination.State? = nil
        @Presents var editDestination: EditDestination.State? = nil
        @Presents var alert: AlertFeature.State? = nil
        var isLoading: Bool {
            isApiLoading || isAuthLoading || isExportLoading
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
        case signOutTapped
        case signOutReceived(AppResult<UserRole>)
        case editDestination(PresentationAction<EditDestination.Action>)
        case destination(PresentationAction<Destination.Action>)
        case alert(PresentationAction<AlertFeature.Action>)
    }

    @Dependency(RouteDataFetcherKey.self) var routeDataFetcher
    @Dependency(\.authService) var authService
    @Dependency(\.dismiss) var dismiss

    var body: some ReducerOf<FestivalDashboardFeature> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .onEdit:
                state.editDestination = .festival(FestivalEditFeature.State(state.festival))
                return .none
            case .periodTapped:
                state.destination = .periods(PeriodListFeature.State(festivalId: state.festival.id))
                return .none
            case .districtsTapped:
                state.destination = .districts(.init(state.festival))
                return .none
            case .dismissTapped:
                return .dismiss
            case .changePasswordTapped:
                state.destination = .changePassword(ChangePasswordFeature.State())
                return .none
            case .updateEmailTapped:
                state.destination = .updateEmail(UpdateEmailFeature.State())
                return .none
            case .signOutTapped:
                state.isAuthLoading = true
                return .task(Action.signOutReceived) {
                    try await authService.signOut()
                }
            case .signOutReceived(.failure(let error)):
                state.isAuthLoading = false
                state.alert = AlertFeature.error("ログアウトに失敗しました　\(error.message)")
                return .none
            case .editDestination(.presented(.festival(.putReceived(.success)))):
                state.editDestination = nil
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
        .ifLet(\.$editDestination, action: \.editDestination)
        .ifLet(\.$alert, action: \.alert)
    }
}

extension FestivalDashboardFeature.Destination.State: Equatable {}
extension FestivalDashboardFeature.Destination.Action: Equatable {}
extension FestivalDashboardFeature.EditDestination.State: Equatable {}
extension FestivalDashboardFeature.EditDestination.Action: Equatable {}

extension FestivalDashboardFeature.State {
    init(_ festival: Festival) {
        self._festival = FetchOne(festival)
    }
}
