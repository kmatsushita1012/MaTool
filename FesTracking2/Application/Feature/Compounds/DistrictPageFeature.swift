//
//  DistrictPage.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/04/02.
//

//import ComposableArchitecture
//
//@Reducer
//struct DistrictPageFeature{
//    
//    @Dependency(\.apiClient) var apiClient
//    
//    @ObservableState
//    struct State: Equatable{
//        var id: String
//        var detail: DistrictDetailFeature.State
//        var route: RouteSummariesFeature.State
//        @Presents var routePage: RouteDetailFeature.State?
//    }
//    
//    enum Action: Equatable{
//        case loaded
//        case detail(DistrictDetailFeature.Action)
//        case route(RouteSummariesFeature.Action)
//    }
//    
//    var body: some ReducerOf<DistrictPageFeature> {
//        Scope(state: \.detail, action: \.detail){ DistrictDetailFeature() }
//        Scope(state: \.route, action: \.route){ RouteSummariesFeature() }
//        Reduce{ state, action in
//            switch action {
//            case .loaded:
//                return .run { [id = state.id] send in
//                    let detailResult = await self.apiClient.getDistrictDetail(id)
//                    let routeResult = await self.apiClient.getRouteSummaries(id)
//                    
//                    await send(.detail(.received( detailResult)))
//                    await send(.route(.received( routeResult)))
//                }
//                
//            case .detail:
//                return .none
//            case .route(.selected(_)):
//                state.routePage = RouteDetailFeature.State()
//                return .none
//            case .route:
//                return .none
//            }
//        }
//    }
//}
//
