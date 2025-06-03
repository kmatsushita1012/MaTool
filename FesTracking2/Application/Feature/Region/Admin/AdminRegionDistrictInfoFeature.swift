//
//  AdminRegionDistrictInfoFeature.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/05/12.
//

import ComposableArchitecture

@Reducer
struct AdminRegionDistrictInfoFeature {
    
    @Dependency(\.apiClient) var apiClient
    @Dependency(\.accessToken) var accessToken
    
    @ObservableState
    struct State: Equatable {
        let district: PublicDistrict
        let routes: [RouteSummary]
        @Presents var export: AdminRouteExportFeature.State?
        @Presents var alert: OkAlert.State?
    }
    
    @CasePathable
    enum Action: Equatable {
        case exportTapped(RouteSummary)
        case exportPrepared(Result<PublicRoute,ApiError>)
        case dismissTapped
        case export(PresentationAction<AdminRouteExportFeature.Action>)
        case alert(PresentationAction<OkAlert.Action>)
    }
    
    var body: some ReducerOf<AdminRegionDistrictInfoFeature> {
        Reduce{ state, action in
            switch action {
            case .exportTapped(let route):
                return .run{ send in
                    let result = await apiClient.getRoute(route.id, accessToken.value)
                    await send(.exportPrepared(result))
                }
            case .exportPrepared(.success(let route)):
                state.export = .init(title: route.text(format: "D m/d T"), route: route.toModel())
                return .none
            case .exportPrepared(.failure(let error)):
                state.alert = OkAlert.make("情報の取得に失敗しました。\n\(error.localizedDescription)")
                return .none
            case .dismissTapped:
                return .none
            case .export(.presented(.dismissTapped)), .export(.dismiss):
                state.export = nil
                return .none
            case .export:
                return .none
            case .alert(.presented(.okTapped)):
                state.alert = nil
                return .none
            case .alert:
                return .none
            }
        }
        .ifLet(\.$alert, action: \.alert)
    }
}
