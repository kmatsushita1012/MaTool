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
        case edit(FestivalEditFeature)
        case districts(HeadquarterDistrictListFeature)
        case periods(PeriodListFeature)
        case changePassword(ChangePassword)
        case updateEmail(UpdateEmail)
    }

    @ObservableState
    struct State: Equatable {
        @FetchOne var festival: Festival
        @FetchAll var districts: [District]

        var isApiLoading: Bool = false
        var isAuthLoading: Bool = false
        var isExportLoading: Bool = false
        var folder: ExportedFolder? = nil

        @Presents var destination: Destination.State? = nil
        @Presents var alert: Alert.State? = nil
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
        case homeTapped
        case changePasswordTapped
        case updateEmailTapped
        case signOutTapped
        case signOutReceived(Result<UserRole, AuthError>)
        case destination(PresentationAction<Destination.Action>)
        case alert(PresentationAction<Alert.Action>)
    }

    @Dependency(\.apiRepository) var apiRepository
    @Dependency(RouteDataFetcherKey.self) var routeDataFetcher
    @Dependency(\.authService) var authService
    @Dependency(\.dismiss) var dismiss

    var body: some ReducerOf<FestivalDashboardFeature> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .onEdit:
                state.destination = .edit(FestivalEditFeature.State(state.festival))
                return .none
            case .periodTapped:
                state.destination = .periods(PeriodListFeature.State(festivalId: state.festival.id))
                return .none
            case .districtsTapped:
                state.destination = .districts(.init(state.festival))
                return .none
            case .homeTapped:
                return .run { _ in
                    await dismiss()
                }
            case .changePasswordTapped:
                state.destination = .changePassword(ChangePassword.State())
                return .none
            case .updateEmailTapped:
                state.destination = .updateEmail(UpdateEmail.State())
                return .none
            case .signOutTapped:
                state.isAuthLoading = true
                return .run { send in
                    let result = await authService.signOut()
                    await send(.signOutReceived(result))
                }
            case .signOutReceived(.success):
                state.isAuthLoading = false
                return .none
            case .signOutReceived(.failure(let error)):
                state.isAuthLoading = false
                state.alert = Alert.error("ログアウトに失敗しました　\(error.localizedDescription)")
                return .none
            case .destination(.presented(.edit(.putReceived(.success)))):
                state.destination = nil
                return .none
            case .destination(.presented(.changePassword(.received(.success)))):
                state.destination = nil
                state.alert = Alert.success("パスワードが変更されました")
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

extension FestivalDashboardFeature.State {
    init(_ festival: Festival) {
        self._festival = FetchOne(wrappedValue: festival)
        self._districts = FetchAll(District.where { $0.festivalId == festival.id })
    }
}
