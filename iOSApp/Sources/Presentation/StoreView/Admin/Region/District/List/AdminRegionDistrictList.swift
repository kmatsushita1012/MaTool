//
//  AdminDistrictList.swift
//  MaTool
//
//  Created by 松下和也 on 2025/05/12.
//

import ComposableArchitecture
import Foundation
import Shared
import SQLiteData

@Reducer
struct AdminDistrictList {
    
    @ObservableState
    struct State: Equatable {
        @FetchOne var district: District
        @FetchAll var routes: [RouteSlot]
        
        var isApiLoading: Bool = false
        var isExportLoading: Bool = false
        var folder: ExportedFolder? = nil
        @Presents var export: RouteEditFeature.State?
        @Presents var alert: Alert.State?
        var isLoading: Bool {
            isApiLoading || isExportLoading
        }
    }
    
    @CasePathable
    enum Action: Equatable, BindableAction {
        case binding(BindingAction<State>)
        case exportTapped(RouteSlot)
        case exportPrepared(Result<RouteSlot, APIError>)
        case dismissTapped
        case batchExportTapped
        case batchExportPrepared(Result<[URL], APIError>)
        case export(PresentationAction<RouteEditFeature.Action>)
        case alert(PresentationAction<Alert.Action>)
    }
    
    @Dependency(\.apiRepository) var apiRepository
    @Dependency(RouteDataFetcherKey.self) var dataFetcher
    @Dependency(\.dismiss) var dismiss
    
    var body: some ReducerOf<AdminDistrictList> {
        BindingReducer()
        Reduce{ state, action in
            switch action {
            case .binding:
                return .none
            case .exportTapped(let item):
                guard let route = item.route else { return .none }
                state.isApiLoading = true
                return .run{ send in
                    let result = await task { try await dataFetcher.fetch(routeID: route.id) }
                    await send(.exportPrepared(result.map{ _ in item }))
                }
            case .exportPrepared(.success(let item)):
                state.isApiLoading = false
                guard let route = item.route else { return .none }
                state.export = RouteEditFeature.State(
                    mode: .preview,
                    route: route,
                    district: state.district,
                    period: item.period
                )
                return .none
            case .exportPrepared(.failure(let error)):
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
            RouteEditFeature()
        }
        .ifLet(\.$alert, action: \.alert)
    }
    
    func batchExportEffect(_ items: [RouteSlot]) -> Effect<Action> {
        .run { send in
            //非同期並列にするとBEでアクセス過多
            let result = await task({
                var urls: [URL] = []
                for item in items {
                    guard let route = item.route,
                          let _ = try? await dataFetcher.fetch(routeID: route.id),
                          let snapshotter = await RouteSnapshotter(route),
                          let image = try? await snapshotter.take(),
                          let url = await snapshotter.createPDF(with: image, path: "") else { continue } //FIXME
                    urls.append(url)
                }
                return urls
            }, defaultError: APIError.unknown(message: ""))
            await send(.batchExportPrepared(result))
        }
    }
}

extension AdminDistrictList.State{
    init(_ district: District){
        self._district = FetchOne(wrappedValue: district)
        self._routes = .init(districtId: district.id, latest: true)
    }
}
