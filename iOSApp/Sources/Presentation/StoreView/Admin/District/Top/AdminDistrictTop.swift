//
//  AdminDistrictTop.swift
//  MaTool
//
//  Created by 松下和也 on 2025/04/17.
//

import ComposableArchitecture
import Foundation
import Shared
import SQLiteData

@Reducer
struct AdminDistrictTop {
    
    @Reducer
    enum Destination {
        case edit(AdminDistrictEdit)
        case route(RouteEditFeature)
        case location(AdminLocation)
        case changePassword(ChangePassword)
        case updateEmail(UpdateEmail)
    }
    
    @ObservableState
    struct State:Equatable {
        
        @FetchOne var district: District
        @FetchAll var routes: [RouteSlot]
        @FetchAll var periods: [Period]
        
        var isRouteLoading: Bool = false
        var isAWSLoading: Bool = false
        
        // Navigation
        @Presents var destination: Destination.State?
        @Presents var alert: Alert.State?
    }
    
    @CasePathable
    enum Action: Equatable {
        case onEdit
        case onRouteEdit(RouteSlot)
        case changePasswordTapped
        case updateEmailTapped
        case routeCreatePrepared
        case locationPrepared(isTracking: Bool, Interval: Interval?)
        case onLocation
        case destination(PresentationAction<Destination.Action>)
        case signOutTapped
        case signOutReceived(TaskResult<UserRole>)
        case routeEditReceived(TaskResult<RouteSlot>)
        case dismissTapped
        case alert(PresentationAction<Alert.Action>)
    }
    
    @Dependency(\.locationService) var locationService
    @Dependency(\.authService) var authService
    @Dependency(RouteDataFetcherKey.self) var routeDateFetcher
    @Dependency(\.dismiss) var dismiss
    
    var body: some ReducerOf<AdminDistrictTop> {
        Reduce{ state, action in
            switch action {
            case .onEdit:
                state.destination = .edit(.init(state.district))
                return .none
            case .onRouteEdit(let item):
                state.isRouteLoading = true
                if let route = item.route {
                    return .task(Action.routeEditReceived) { [state] in
                        async let listTask: () = routeDateFetcher.fetchAll(districtID: state.district.id, query: .all)
                        async let detailTask: () = routeDateFetcher.fetch(routeID: route.id)
                        let _ = try await (listTask, detailTask)
                        return item
                    }
                } else {
                    return .task(Action.routeEditReceived) { [state] in
                        try await routeDateFetcher.fetchAll(districtID: state.district.id, query: .all)
                        return item
                    }
                }
            case .changePasswordTapped:
                state.destination = .changePassword(ChangePassword.State())
                return .none
            case .updateEmailTapped:
                state.destination = .updateEmail(UpdateEmail.State())
                return .none
            case .routeEditReceived(.success(let item)):
                state.isRouteLoading = false
                if let route = item.route {
                    state.destination = .route(
                        RouteEditFeature.State(mode: .update, route: route, district: state.district, period: item.period)
                    )
                } else {
                    let route = Route(id: UUID().uuidString, districtId: state.district.id, periodId: item.period.id)
                    state.destination = .route(
                        RouteEditFeature.State(
                            mode: .create,
                            route: route,
                            district: state.district,
                            period: item.period
                        )
                    )
                }
                return .none
            case .routeEditReceived(.failure(let error)):
                state.isRouteLoading = false
                state.alert = .error(error.localizedDescription)
                return .none
            case .locationPrepared(isTracking: let isTracking, Interval: let interval):
                state.destination = .location(
                    AdminLocation.State(
                        id: state.district.id,
                        isTracking: isTracking,
                        selectedInterval: interval ?? Interval.sample
                    )
                )
                return .none
            case .onLocation:
                return .run { send in
                    let isTracking = await locationService.getIsTracking()
                    let interval = await locationService.getInterval()
                    await send(.locationPrepared(isTracking: isTracking, Interval: interval))
                }
            case .destination(.presented(let childAction)):
                switch childAction {
                case .edit(.postReceived(.success)):
                    state.destination = nil
                    return .none
                case .changePassword(.received(.success)):
                    state.destination = nil
                    state.alert = Alert.success("パスワードが変更されました")
                    return .none
                default:
                    return .none
                }
            case .signOutTapped:
                state.isAWSLoading = true
                return .task(Action.signOutReceived) {
                    try await authService.signOut()
                }
            case .signOutReceived(.failure(let error)):
                state.isAWSLoading = false
                state.alert = .error("ログアウトに失敗しました。 \(error.localizedDescription)")
                return .none
            case .dismissTapped:
                return .dismiss
            case .alert(.presented(.okTapped)):
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

extension AdminDistrictTop.Destination.State: Equatable {}
extension AdminDistrictTop.Destination.Action: Equatable {}

extension AdminDistrictTop.State{
    var isLoading: Bool {
        isAWSLoading || isRouteLoading
    }
    
    init(_ district: District){
        self._district = FetchOne(wrappedValue: district)
        self._routes = .init(districtId: district.id, latest: true)
    }
}
