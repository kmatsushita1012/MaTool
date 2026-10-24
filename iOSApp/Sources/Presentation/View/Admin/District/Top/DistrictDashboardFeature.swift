//
//  DistrictDashboardFeature.swift
//  MaTool
//
//  Created by 松下和也 on 2025/04/17.
//

import ComposableArchitecture
import Foundation
import Shared

@Reducer
struct DistrictDashboardFeature {
    enum ExportKind: Equatable {
        case submission
        case table
    }
    
    @Reducer
    enum Destination {
        case edit(DistrictEditFeature)
        case route(RouteEditFeature)
        case location(LocationTrackingFeature)
        case changePassword(ChangePasswordFeature)
        case updateEmail(UpdateEmailFeature)
    }
    
    @ObservableState
    struct State:Equatable {
        var district: District
        @Shared fileprivate var appState: AppState?

        var routes: [RouteSlot] {
            appState?.routeSlots(for: district.id) ?? []
        }
        
        var isAWSLoading: Bool = false
        var isRouteLoading: Bool = false
        var activeExportKind: ExportKind? = nil
        var url: URL? = nil
        
        // Navigation
        @Presents var destination: Destination.State?
        @Presents var alert: AlertFeature.State?

        init(_ district: District, appState: Shared<AppState?>) {
            self.district = district
            self._appState = appState
        }
    }
    
    @CasePathable
    enum Action: Equatable, BindableAction {
        case binding(BindingAction<State>)
        case onEdit
        case onRouteEdit(RouteSlot)
        case routeEditReceived(AppResult<RoutePack?>)
        case changePasswordTapped
        case updateEmailTapped
        case routeCreatePrepared
        case locationPrepared(
            isTracking: Bool,
            interval: Interval?,
            permissionState: LocationPermissionState
        )
        case onLocation
        case submissionExportTapped
        case tableExportTapped
        case exportReceived(AppResult<URL>)
        case destination(PresentationAction<Destination.Action>)
        case signOutTapped
        case signOutReceived(VoidAppResult)
        case dismissTapped
        case alert(PresentationAction<AlertFeature.Action>)
    }
    
    @Dependency(\.locationUsecase) var locationUsecase
    @Dependency(SignOutUseCaseKey.self) var signOutUseCase
    @Dependency(FetchRoutePackUseCaseKey.self) var fetchRoutePackUseCase
    @Dependency(LoadRouteStateUseCaseKey.self) var loadRouteStateUseCase
    @Dependency(\.dismiss) var dismiss
    
    var body: some ReducerOf<DistrictDashboardFeature> {
        BindingReducer()
        Reduce{ state, action in
            switch action {
            case .binding:
                return .none
            case .onEdit:
                do {
                    state.destination = .edit(try .init(state.district, appState: state.$appState))
                } catch {
                    state.alert = .error("情報の取得に失敗しました")
                }
                return .none
            case .onRouteEdit(let item):
                if let route = item.route {
                    state.isRouteLoading = true
                    return .task(Action.routeEditReceived) { [routeId = route.id, appState = state.$appState] in
                        try await loadRouteStateUseCase(routeId: routeId, appState: appState)
                    }
                }
                let route = Route(
                    id: UUID().uuidString,
                    districtId: state.district.id,
                    periodId: item.period.id,
                    visibility: state.district.visibility
                )
                do {
                    state.destination = .route(try .init(mode: .create, route: route, appState: state.$appState))
                } catch {
                    state.alert = .error(error.localizedDescription)
                }
                return .none
            case .routeEditReceived(.success(let pack)):
                state.isRouteLoading = false
                guard let pack else { return .none }
                let draft = RouteDraft(route: pack.route, points: pack.points, passages: pack.passages)
                do {
                    state.destination = .route(try .init(mode: .update, draft: draft, appState: state.$appState))
                } catch {
                    state.alert = .error(error.localizedDescription)
                }
                return .none
            case .routeEditReceived(.failure(let error)):
                state.isRouteLoading = false
                state.alert = .error(error.message)
                return .none
            case .changePasswordTapped:
                state.destination = .changePassword(ChangePasswordFeature.State())
                return .none
            case .updateEmailTapped:
                state.destination = .updateEmail(UpdateEmailFeature.State())
                return .none
            case .locationPrepared(
                isTracking: let isTracking,
                interval: let interval,
                permissionState: let permissionState
            ):
                state.destination = .location(
                    LocationTrackingFeature.State(
                        id: state.district.id,
                        isTracking: isTracking,
                        selectedInterval: interval ?? Interval.sample,
                        permissionState: permissionState,
                        appState: state.$appState
                    )
                )
                return .none
            case .onLocation:
                return .run { send in
                    let preparation = await locationUsecase.prepareTracking()
                    await send(.locationPrepared(
                        isTracking: preparation.isTracking,
                        interval: preparation.interval,
                        permissionState: preparation.permissionState
                    ))
                }
            case .submissionExportTapped:
                state.activeExportKind = .submission
                return exportEffect(state: state, path: state.district.pdfFileName(), includesRouteMap: true)
            case .tableExportTapped:
                state.activeExportKind = .table
                return exportEffect(state: state, path: state.district.pdfFileName(suffix: "_行動表"), includesRouteMap: false)
            case .exportReceived(.success(let url)):
                state.activeExportKind = nil
                state.url = url
                return .none
            case .exportReceived(.failure(let error)):
                state.activeExportKind = nil
                state.alert = .error(error.message)
                return .none
            case .destination(.presented(let childAction)):
                switch childAction {
                case .edit(.postReceived(.success)):
                    if let updated = state.appState?.district(id: state.district.id) {
                        state.district = updated
                    }
                    state.destination = nil
                    return .none
                case .changePassword(.received(.success)):
                    state.destination = nil
                    state.alert = AlertFeature.success("パスワードが変更されました")
                    return .none
                default:
                    return .none
                }
            case .signOutTapped:
                state.isAWSLoading = true
                return .task(Action.signOutReceived) {
                    try await signOutUseCase()
                }
                .cancellable(id: SceneSessionCancellationID.active, cancelInFlight: true)
            case .signOutReceived(.failure(let error)):
                state.isAWSLoading = false
                state.alert = .error("ログアウトに失敗しました。 \(error.message)")
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

extension DistrictDashboardFeature.Destination.State: Equatable {}
extension DistrictDashboardFeature.Destination.Action: Equatable {}

extension DistrictDashboardFeature.State{
    var isLoading: Bool {
        isAWSLoading || isRouteLoading || activeExportKind != nil
    }
    
    var isSubmissionExportLoading: Bool {
        activeExportKind == .submission
    }
    
    var isTableExportLoading: Bool {
        activeExportKind == .table
    }
    
}

private extension DistrictDashboardFeature {
    func exportEffect(state: State, path: String, includesRouteMap: Bool) -> Effect<Action> {
        .task(Action.exportReceived) {
            let renderer = await PDFRenderer(path: path)
            let routes = state.routes.compactMap(\.route)
            var routePacks: [RoutePack] = []
            for route in routes {
                guard let pack = try? await fetchRoutePackUseCase(routeId: route.id) else { continue }
                routePacks.append(pack)
            }
            let tableSnapshotter = await ActionTableSnapshotter(
                district: state.district,
                slots: state.routes,
                routePacks: routePacks
            )
            let tablePages = await tableSnapshotter.takeAll()
            for page in tablePages {
                await renderer.addPage(with: page)
            }
            guard includesRouteMap else {
                let url = await renderer.finalize()
                return url
            }
            for pack in routePacks {
                guard let snapshotter = try? await RouteSnapshotter(route: pack.route, points: pack.points),
                      let image = try? await snapshotter.take() else { continue }
                await renderer.addPage(with: image)
            }
            let url = await renderer.finalize()
            return url
        }
    }
}
