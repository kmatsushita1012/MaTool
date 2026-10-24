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
        let districtId: District.ID
        @Shared fileprivate var appState: AppState?

        var district: District {
            appState!.festivalState.districts.first { $0.id == districtId }!
        }

        var periods: [Period] {
            appState?.festivalState.periods ?? []
        }

        var routes: [RouteSlot] {
            let districtState = appState?.districtState
            return periods.map { period in
                RouteSlot(
                    period: period,
                    route: districtState?.districtId == districtId
                        ? districtState?.routes.first { $0.periodId == period.id }
                        : nil
                )
            }
        }
        
        var isAWSLoading: Bool = false
        var activeExportKind: ExportKind? = nil
        var url: URL? = nil
        
        // Navigation
        @Presents var destination: Destination.State?
        @Presents var alert: AlertFeature.State?

        init(_ district: District, appState: Shared<AppState?>) {
            self.districtId = district.id
            self._appState = appState
        }
    }
    
    @CasePathable
    enum Action: Equatable, BindableAction {
        case binding(BindingAction<State>)
        case onEdit
        case onRouteEdit(RouteSlot)
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
    @Dependency(\.dismiss) var dismiss
    
    var body: some ReducerOf<DistrictDashboardFeature> {
        BindingReducer()
        Reduce{ state, action in
            switch action {
            case .binding:
                return .none
            case .onEdit:
                state.destination = .edit(.init(state.district, appState: state.$appState))
                return .none
            case .onRouteEdit(let item):
                do {
                    if let route = item.route {
                        state.destination = .route(try .init(mode: .update, route: route, appState: state.$appState))
                    } else {
                        let route = Route(
                            id: UUID().uuidString,
                            districtId: state.district.id,
                            periodId: item.period.id,
                            visibility: state.district.visibility
                        )
                        state.destination = .route(try .init(mode: .create, route: route, appState: state.$appState))
                    }
                } catch {
                    state.alert = .error(error.localizedDescription)
                }
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
                    let isTracking = await locationUsecase.getIsTracking()
                    let interval = await locationUsecase.getInterval()
                    let permissionState = await locationUsecase.locationPermissionState()
                    await send(
                        .locationPrepared(
                            isTracking: isTracking,
                            interval: interval,
                            permissionState: permissionState
                        )
                    )
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
        isAWSLoading || activeExportKind != nil
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
            var passagesByRouteID: [Route.ID: [RoutePassage]] = [:]
            var pointsByRouteID: [Route.ID: [Point]] = [:]
            for route in routes {
                guard let pack = try? await fetchRoutePackUseCase(routeId: route.id) else { continue }
                passagesByRouteID[route.id] = pack.passages
                pointsByRouteID[route.id] = pack.points
            }
            let tableSnapshotter = await ActionTableSnapshotter(
                district: state.district,
                slots: state.routes,
                passagesByRouteID: passagesByRouteID
            )
            let tablePages = await tableSnapshotter.takeAll()
            for page in tablePages {
                await renderer.addPage(with: page)
            }
            guard includesRouteMap else {
                let url = await renderer.finalize()
                return url
            }
            for route in routes {
                guard let points = pointsByRouteID[route.id] else { continue }
                guard let snapshotter = try? await RouteSnapshotter(route: route, points: points),
                      let image = try? await snapshotter.take() else { continue }
                await renderer.addPage(with: image)
            }
            let url = await renderer.finalize()
            return url
        }
    }
}
