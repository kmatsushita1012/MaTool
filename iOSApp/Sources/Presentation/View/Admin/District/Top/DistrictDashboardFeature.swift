//
//  DistrictDashboardFeature.swift
//  MaTool
//
//  Created by 松下和也 on 2025/04/17.
//

import ComposableArchitecture
import Foundation
import Shared
import SQLiteData

@Reducer
struct DistrictDashboardFeature {
    
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
        
        @FetchOne var district: District
        @FetchAll var routes: [RouteSlot]
        @FetchAll var periods: [Period]
        
        var isRouteLoading: Bool = false
        var isAWSLoading: Bool = false
        var isExportLoading: Bool = false
        var url: URL? = nil
        
        // Navigation
        @Presents var destination: Destination.State?
        @Presents var alert: AlertFeature.State?
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
        case submissionExportTapped
        case tableExportTapped
        case exportReceived(TaskResult<URL>)
        case destination(PresentationAction<Destination.Action>)
        case signOutTapped
        case signOutReceived(TaskResult<UserRole>)
        case routeEditReceived(TaskResult<RouteSlot>)
        case dismissTapped
        case alert(PresentationAction<AlertFeature.Action>)
    }
    
    @Dependency(\.locationService) var locationService
    @Dependency(\.authService) var authService
    @Dependency(RouteDataFetcherKey.self) var routeDateFetcher
    @Dependency(\.dismiss) var dismiss
    
    var body: some ReducerOf<DistrictDashboardFeature> {
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
                state.destination = .changePassword(ChangePasswordFeature.State())
                return .none
            case .updateEmailTapped:
                state.destination = .updateEmail(UpdateEmailFeature.State())
                return .none
            case .routeEditReceived(.success(let item)):
                state.isRouteLoading = false
                if let route = item.route{
                    state.destination = try? { .route(try .init(mode: .update, route: route)) }()
                } else {
                    let route = Route(id: UUID().uuidString, districtId: state.district.id, periodId: item.period.id, visibility: state.district.visibility)
                    state.destination = try? { .route(try .init(mode: .create, route: route)) }()
                }
                return .none
            case .routeEditReceived(.failure(let error)):
                state.isRouteLoading = false
                state.alert = .error(error.localizedDescription)
                return .none
            case .locationPrepared(isTracking: let isTracking, Interval: let interval):
                state.destination = .location(
                    LocationTrackingFeature.State(
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
            case .submissionExportTapped:
                state.isExportLoading = true
                return exportEffect(state: state, path: "\(state.district.name).pdf", includesRouteMap: true)
            case .tableExportTapped:
                state.isExportLoading = true
                return exportEffect(state: state, path: "\(state.district.name)_行動表.pdf", includesRouteMap: false)
            case .exportReceived(.success(let url)):
                state.isExportLoading = false
                state.url = url
                return .none
            case .exportReceived(.failure(let error)):
                state.isExportLoading = false
                state.alert = .error(error.localizedDescription)
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

extension DistrictDashboardFeature.Destination.State: Equatable {}
extension DistrictDashboardFeature.Destination.Action: Equatable {}

extension DistrictDashboardFeature.State{
    var isLoading: Bool {
        isAWSLoading || isRouteLoading || isExportLoading
    }
    
    init(_ district: District){
        self._district = FetchOne(district)
        self._routes = .init(districtId: district.id, latest: true)
    }
}

private extension DistrictDashboardFeature {
    func exportEffect(state: State, path: String, includesRouteMap: Bool) -> Effect<Action> {
        .task(Action.exportReceived) {
            let renderer = await PDFRenderer(path: path)
            let tableSnapshotter = await ActionTableSnapshotter(district: state.district, slots: state.routes)
            let tablePages = await tableSnapshotter.takeAll()
            for page in tablePages {
                await renderer.addPage(with: page)
            }
            guard includesRouteMap else {
                let url = await renderer.finalize()
                return url
            }
            for item in state.routes {
                guard let route = item.route,
                      let _ = try? await routeDateFetcher.fetch(routeID: route.id),
                      let snapshotter = try? await RouteSnapshotter(route),
                      let image = try? await snapshotter.take() else { continue }
                await renderer.addPage(with: image)
            }
            let url = await renderer.finalize()
            return url
        }
    }
}
