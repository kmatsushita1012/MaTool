//
//  AdminDistrictTop.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/04/17.
//

import ComposableArchitecture

@Reducer
struct AdminDistrictTop {
    
    @Reducer
    enum Destination {
        case edit(AdminDistrictEdit)
        case route(AdminRouteInfo)
        case export(AdminRouteExport)
        case location(AdminLocation)
        case changePassword(ChangePassword)
        case updateEmail(UpdateEmail)
    }
    
    @ObservableState
    struct State:Equatable {
        var district: PublicDistrict
        var routes: [RouteSummary]
        var isDistrictLoading: Bool = false
        var isRoutesLoading: Bool = false
        var isRouteLoading: Bool = false
        var isExportLoading: Bool = false
        var isAWSLoading: Bool = false
        @Presents var destination: Destination.State?
        @Presents var alert: Alert.State?
        var isLoading: Bool {
            isDistrictLoading || isRoutesLoading || isAWSLoading || isRouteLoading || isExportLoading
        }
    }
    
    @CasePathable
    enum Action: Equatable {
        case onEdit
        case onRouteAdd
        case onRouteEdit(RouteSummary)
        case onRouteExport(RouteSummary)
        case changePasswordTapped
        case updateEmailTapped
        case getDistrictReceived(Result<PublicDistrict,ApiError>)
        case getRoutesReceived(Result<[RouteSummary],ApiError>)
        case editPrepared(Result<DistrictTool,ApiError>)
        case routeEditPrepared(Result<RouteInfo,ApiError>,Result<DistrictTool,ApiError>)
        case routeCreatePrepared(Result<DistrictTool,ApiError>)
        case exportPrepared(Result<RouteInfo,ApiError>)
        case onLocation
        case destination(PresentationAction<Destination.Action>)
        case signOutTapped
        case signOutReceived(Result<UserRole, AuthError>)
        case homeTapped
        case alert(PresentationAction<Alert.Action>)
    }
    
    @Dependency(\.apiRepository) var apiRepository
    @Dependency(\.locationService) var locationService
    @Dependency(\.authService) var authService
    @Dependency(\.dismiss) var dismiss
    
    var body: some ReducerOf<AdminDistrictTop> {
        Reduce{ state, action in
            switch action {
            case .onEdit:
                state.isDistrictLoading = true
                return .run {[id = state.district.id] send in
                    let result = await apiRepository.getTool(id, authService.getAccessToken())
                    await send(.editPrepared(result))
                }
            case .onRouteAdd:
                state.isRouteLoading = true
                return .run {[id = state.district.id] send in
                    let result = await apiRepository.getTool(id, authService.getAccessToken())
                    await send(.routeCreatePrepared(result))
                }
            case .onRouteEdit(let route):
                state.isRouteLoading = true
                return .run { send in
                    let routeResult = await apiRepository.getRoute(route.id, authService.getAccessToken())
                    let toolResult = await apiRepository.getTool(route.districtId, authService.getAccessToken())
                    await send(.routeEditPrepared(routeResult, toolResult))
                }
            case .onRouteExport(let route):
                state.isExportLoading = true
                return .run { send in
                    let result = await apiRepository.getRoute(route.id, authService.getAccessToken())
                    await send(.exportPrepared(result))
                }
            case .changePasswordTapped:
                state.destination = .changePassword(ChangePassword.State())
                return .none
            case .updateEmailTapped:
                state.destination = .updateEmail(UpdateEmail.State())
                return .none
            case .getDistrictReceived(let result):
                state.isDistrictLoading = false
                switch result {
                case .success(let value):
                    state.district = value
                case .failure(let error):
                    state.alert = Alert.error("情報の取得に失敗しました。 \(error.localizedDescription)")
                }
                return .none
            case .getRoutesReceived(let result):
                state.isRoutesLoading = false
                switch result {
                case .success(let value):
                    state.routes = value.sorted()
                case .failure(let error):
                    state.alert = Alert.error("情報の取得に失敗しました。 \(error.localizedDescription)")
                }
                return .none
            case .editPrepared(let result):
                state.isDistrictLoading = false
                switch result {
                case .success(let tool):
                    state.destination = .edit(
                        AdminDistrictEdit.State(
                            item: state.district.toModel(),
                            tool: tool
                        )
                    )
                case .failure(let error):
                    state.alert = Alert.error("情報の取得に失敗しました。 \(error.localizedDescription)")
                }
                return .none
            case .routeEditPrepared(let routeResult, let toolResult):
                state.isRouteLoading = false
                if case let .success(route) = routeResult,
                   case let .success(tool) = toolResult{
                    state.destination = .route(
                        AdminRouteInfo.State(
                            mode: .edit(route.toModel()),
                            milestones: tool.milestones,
                            origin: tool.base
                        )
                    )
                } else {
                    state.alert = Alert.error("情報の取得に失敗しました。")
                }
                return .none
            case .routeCreatePrepared(let result):
                state.isRouteLoading = false
                switch result {
                case .success(let tool):
                    state.destination = .route(
                        AdminRouteInfo.State(
                            mode: .create(
                                state.district.id,
                                tool.spans.first ?? Span.sample
                            ),
                            milestones: tool.milestones,
                            origin: tool.base
                        )
                    )
                case .failure(let error):
                    state.alert = Alert.error("情報の取得に失敗しました。 \(error.localizedDescription)")
                }
                return .none
            case .exportPrepared(let result):
                state.isExportLoading = false
                switch result {
                case .success(let value):
                    state.destination = .export(
                        AdminRouteExport.State(route: value)
                    )
                case .failure(let error):
                    state.alert = Alert.error("情報の取得に失敗しました。 \(error.localizedDescription)")
                }
                return .none
            case .onLocation:
                state.destination = .location(
                    AdminLocation.State(
                        id: state.district.id,
                        isTracking: locationService.isTracking)
                )
                return .none
            case .destination(.presented(let childAction)):
                switch childAction {
                case .edit(.postReceived(.success)),
                    .route(.postReceived(.success)),
                    .route(.deleteReceived(.success)):
                    state.destination = nil
                    state.isDistrictLoading = true
                    state.isRoutesLoading = true
                    return .merge(
                        .run {[id = state.district.id] send in
                            let result = await apiRepository.getDistrict(id)
                            await send(.getDistrictReceived(result))
                        },
                        .run {[id = state.district.id] send in
                            let result = await apiRepository.getRoutes(id, authService.getAccessToken())
                            await send(.getRoutesReceived(result))
                        }
                    )
                case .changePassword(.received(.success)):
                    state.destination = nil
                    state.alert = Alert.success("パスワードが変更されました")
                    return .none
                case .edit,
                    .route,
                    .location,
                    .export,
                    .changePassword,
                    .updateEmail:
                    return .none
                }
            case .destination(.dismiss):
                return .none
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
            case .alert(_):
                return .none
            }
        }
        .ifLet(\.$destination, action: \.destination)
        .ifLet(\.$alert, action: \.alert)
    }
}

extension AdminDistrictTop.Destination.State: Equatable {}
extension AdminDistrictTop.Destination.Action: Equatable {}
