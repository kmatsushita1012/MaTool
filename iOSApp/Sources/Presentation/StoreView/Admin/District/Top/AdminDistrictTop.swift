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
        case route(AdminRouteEdit)
        case location(AdminLocation)
        case changePassword(ChangePassword)
        case updateEmail(UpdateEmail)
    }
    
    @ObservableState
    struct State:Equatable {
        @Selection struct Item: Equatable{
            let period: Period
            let route: Route?
        }
        
        @FetchOne var district: District
        @FetchAll var routes: [Item]
        @FetchAll var periods: [Period]
        
        var isDistrictLoading: Bool = false
        var isRoutesLoading: Bool = false
        var isRouteLoading: Bool = false
        var isAWSLoading: Bool = false
        
        // Navigation
        @Presents var destination: Destination.State?
        @Presents var alert: Alert.State?
    }
    
    @CasePathable
    enum Action: Equatable {
        case onEdit
        case onRouteAdd(State.Item)
        case onRouteEdit(State.Item)
        case changePasswordTapped
        case updateEmailTapped
        case routeEditPrepared(State.Item)
        case routeCreatePrepared
        case locationPrepared(isTracking: Bool, Interval: Interval?)
        case onLocation
        case destination(PresentationAction<Destination.Action>)
        case signOutTapped
        case signOutReceived(Result<UserRole, AuthError>)
        case homeTapped
        case alert(PresentationAction<Alert.Action>)
    }
    
    @Dependency(\.locationService) var locationService
    @Dependency(\.authService) var authService
    @Dependency(\.routeDataFetcher) var routeDateFetcher
    @Dependency(\.dismiss) var dismiss
    
    var body: some ReducerOf<AdminDistrictTop> {
        Reduce{ state, action in
            switch action {
            case .onEdit:
                state.isDistrictLoading = true
                return .none
            case .onRouteAdd(let item):
                let route = Route(id: UUID().uuidString, districtId: state.district.id, periodId: item.period.id)
                state.destination = .route(
                    AdminRouteEdit.State(
                        mode: .create,
                        route: route,
                        district: state.district,
                        period: item.period
                    )
                )
                return .none
            case .onRouteEdit(let item):
                state.isRouteLoading = true
                guard let route = item.route else { return .none }
                return .run { send in
                    let result = await task{ try await routeDateFetcher.fetch(routeID: route.id) }
                    // TODO: エラーハンドリング
                    await send(.routeEditPrepared(item))
                }
            case .changePasswordTapped:
                state.destination = .changePassword(ChangePassword.State())
                return .none
            case .updateEmailTapped:
                state.destination = .updateEmail(UpdateEmail.State())
                return .none
            case .routeEditPrepared(let target):
                state.isRouteLoading = false
                guard let route = target.route else { return .none }
                state.destination = .route(
                    AdminRouteEdit.State(mode: .update, route: route, district: state.district, period: target.period)
                )
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
                case .edit(.postReceived(.success)),
                    .route(.postReceived(.success)),
                    .route(.deleteReceived(.success)):
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
                return .run { send in
                    let result = await authService.signOut()
                    await send(.signOutReceived(result))
                }
            case .signOutReceived(let result):
                state.isAWSLoading = false
                if case let .failure(error) = result {
                    state.alert = Alert.error("ログアウトに失敗しました。 \(error.localizedDescription)")
                }
                return .none
            case .homeTapped:
                return .run { _ in
                    await dismiss()
                }
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
        isDistrictLoading || isRoutesLoading || isAWSLoading || isRouteLoading
    }
    
    init(_ district: District){
        self._district = FetchOne(wrappedValue: district)
        let maxYear: Int = FetchAll(Period.where{ $0.festivalId == district.festivalId }).wrappedValue.map(\.date.year).max() ?? SimpleDate.now.year
        let routeQuery = Period
            .where{ $0.festivalId == district.festivalId && $0.date.inYear(maxYear) }
            .leftJoin(Route.all){ $0.id.eq($1.periodId)}
            .select{
                Item.Columns(period: $0, route: $1)
            }
        self._routes = FetchAll(routeQuery)
    }
}

extension AdminDistrictTop.State.Item: Identifiable {
    var id: String { period.id }
}
