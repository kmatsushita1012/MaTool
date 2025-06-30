//
//  AdminRegionDistrictList.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/05/12.
//

import ComposableArchitecture

@Reducer
struct AdminRegionDistrictList {
    
    @Dependency(\.apiClient) var apiClient
    @Dependency(\.authService) var authService
    
    @ObservableState
    struct State: Equatable {
        let district: PublicDistrict
        let routes: [RouteSummary]
        var isLoading: Bool = false
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
    
    var body: some ReducerOf<AdminRegionDistrictList> {
        Reduce{ state, action in
            switch action {
            case .exportTapped(let route):
                state.isLoading = true
                return .run{ send in
                    let result = await apiClient.getRoute(route.id, authService.getAccessToken())
                    await send(.exportPrepared(result))
                }
            case .exportPrepared(.success(let route)):
                state.isLoading = false
                state.export = .init(route: route)
                return .none
            case .exportPrepared(.failure(let error)):
                state.isLoading = false
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
