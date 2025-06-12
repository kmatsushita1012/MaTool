//
//  AdminRegionDistrictInfo.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/05/12.
//

import ComposableArchitecture

@Reducer
struct AdminRegionDistrictInfo {
    
    @Dependency(\.apiClient) var apiClient
    @Dependency(\.accessToken) var accessToken
    
    @ObservableState
    struct State: Equatable {
        let district: PublicDistrict
        let routes: [RouteSummary]
        @Presents var export: AdminRouteExport.State?
        @Presents var alert: OkAlert.State?
    }
    
    @CasePathable
    enum Action: Equatable {
        case exportTapped(RouteSummary)
        case exportPrepared(Result<PublicRoute,ApiError>)
        case dismissTapped
        case export(PresentationAction<AdminRouteExport.Action>)
        case alert(PresentationAction<OkAlert.Action>)
    }
    
    var body: some ReducerOf<AdminRegionDistrictInfo> {
        Reduce{ state, action in
            switch action {
            case .exportTapped(let route):
                return .run{ send in
                    let result = await apiClient.getRoute(route.id, accessToken.value)
                    await send(.exportPrepared(result))
                }
            case .exportPrepared(.success(let route)):
                state.export = .init(route: route)
                return .none
            case .exportPrepared(.failure(let error)):
                state.alert = OkAlert.error("情報の取得に失敗しました。\n\(error.localizedDescription)")
                return .none
            case .dismissTapped:
                return .none
            case .export(.presented(.dismissTapped)),
                .export(.dismiss):
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
