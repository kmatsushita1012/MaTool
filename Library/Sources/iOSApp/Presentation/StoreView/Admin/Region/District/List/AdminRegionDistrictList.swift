//
//  AdminRegionDistrictList.swift
//  MaTool
//
//  Created by 松下和也 on 2025/05/12.
//

import ComposableArchitecture
import Foundation
import Shared

@Reducer
struct AdminRegionDistrictList {
    
    @ObservableState
    struct State: Equatable {
        let region: Region
        let district: District
        let routes: [RouteItem]
        var isApiLoading: Bool = false
        var isExportLoading: Bool = false
        var folder: ExportedFolder? = nil
        @Presents var export: AdminRouteEdit.State?
        @Presents var alert: Alert.State?
        var isLoading: Bool {
            isApiLoading || isExportLoading
        }
    }
    
    @CasePathable
    enum Action: Equatable, BindableAction {
        case binding(BindingAction<State>)
        case exportTapped(RouteItem)
        case exportPrepared(Result<Route,APIError>)
        case dismissTapped
        case batchExportTapped
        case batchExportPrepared(Result<[URL], APIError>)
        case export(PresentationAction<AdminRouteEdit.Action>)
        case alert(PresentationAction<Alert.Action>)
    }
    
    @Dependency(\.apiRepository) var apiRepository
    @Dependency(\.dismiss) var dismiss
    
    var body: some ReducerOf<AdminRegionDistrictList> {
        BindingReducer()
        Reduce{ state, action in
            switch action {
            case .binding:
                return .none
            case .exportTapped(let route):
                state.isApiLoading = true
                return .run{ send in
                    let result = await apiRepository.getRoute(route.id)
                    await send(.exportPrepared(result))
                }
            case .exportPrepared(.success(let route)):
                state.isApiLoading = false
                state.export = AdminRouteEdit.State(
                    mode: .preview,
                    route: route,
                    districtName: state.district.name,
                    milestones: state.region.milestones,
                    origin: Coordinate(latitude: 0, longitude: 0)
                )
                return .none
            case .exportPrepared(.failure(let error)):
                state.isApiLoading = false
                state.alert = Alert.error("情報の取得に失敗しました。\n\(error.localizedDescription)")
                return .none
            case .dismissTapped:
                return .run { _ in
                    await dismiss()
                }
            case .batchExportTapped:
                state.isExportLoading = true
                return batchExportEffect(state.routes)
            case .batchExportPrepared(.success(let value)):
                state.isExportLoading = false
                state.folder = ExportedFolder(value)
                return .none
            case .batchExportPrepared(.failure(let error)):
                state.alert = Alert.error("出力に失敗しました。\n\(error.localizedDescription)")
                return .none
            case .export:
                return .none
            case .alert:
                state.alert = nil
                return .none
            }
        }
        .ifLet(\.$export, action: \.export){
            AdminRouteEdit()
        }
        .ifLet(\.$alert, action: \.alert)
    }
    
    func batchExportEffect(_ items: [RouteItem]) -> Effect<Action> {
        .run { send in
            
            var urls: [URL] = []
            //非同期並列にするとBEでアクセス過多
            for item in items {
                let routeResult = await apiRepository.getRoute(item.id)
                guard let route = routeResult.value else { continue }
                let snapshotter = RouteSnapshotter(route)
                guard let image = try? await snapshotter.take() else { continue }
                guard let url = snapshotter.createPDF(with: image, path: "\(route.text(format: "D_y-m-d_T")).pdf") else { continue }
                urls.append(url)
            }
            await send(.batchExportPrepared(.success(urls)))
        }
    }
}
