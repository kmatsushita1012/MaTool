//
//  InfoListFeature.swift
//  MaTool
//
//  Created by 松下和也 on 2025/05/08.
//

import ComposableArchitecture
import Shared
import SQLiteData

@Reducer
struct InfoListFeature {
    enum MapRequest: Equatable {
        case locations(Festival)
        case route(festival: Festival, district: District, routeId: Route.ID?)
    }
    
    @Reducer
    enum Destination{
        case festival(FestivalInfoFeature)
        case district(DistrictInfoFeature)
    }
    
    @ObservableState
    struct State: Equatable {
        @FetchOne var festival: Festival
        @FetchAll var districts: [District]
        
        var isDismissed: Bool = false
        @Presents var destination: Destination.State? = nil
        @Presents var alert: AlertFeature.State? = nil
        var isLoading: Bool = false
        
        init(festival: Festival) {
            self._festival = FetchOne(festival)
            self._districts = FetchAll(festivalId: festival.id)
        }
    }
    
    @CasePathable
    enum Action: Equatable {
        case festivalTapped
        case districtTapped(District)
        case mapRequested(MapRequest)
        case dismissTapped
        case districtReceived(TaskResult<District>)
        case destination(PresentationAction<Destination.Action>)
        case alert(PresentationAction<AlertFeature.Action>)
    }
    
    @Dependency(DistrictDataFetcherKey.self) var dataFetcher
    @Dependency(\.dismiss) var dismiss
    
    var body: some ReducerOf<InfoListFeature> {
        Reduce { state,action in
            switch action {
            case .festivalTapped:
                state.destination = .festival(FestivalInfoFeature.State(item: state.festival))
                return .none
            case .districtTapped(let district):
                state.isLoading = true
                return .task(Action.districtReceived) {
                    try await dataFetcher.fetch(districtID: district.id)
                    return district
                }
            case .mapRequested:
                return .none
            case .dismissTapped:
                if #available(iOS 17.0, *) {
                    return .dismiss
                } else {
                    state.isDismissed = true
                    return .none
                }
            case .districtReceived(.success(let district)):
                state.destination = .district(DistrictInfoFeature.State(district))
                state.isLoading = false
                return .none
            case .districtReceived(.failure(let error)):
                state.alert = AlertFeature.error(error.localizedDescription)
                state.isLoading = false
                return .none
            case .destination(.presented(.festival(.mapTapped))):
                state.destination = nil
                return .send(.mapRequested(.locations(state.festival)))
            case .destination(.presented(.district(.routeIdReceived(.success(let routeId))))):
                guard let district = state.destination?.district?.district else {
                    return .none
                }
                state.destination = nil
                return .send(.mapRequested(.route(festival: state.festival, district: district, routeId: routeId)))
            case .destination(.presented(.district(.routeIdReceived(.failure(let error))))):
                state.alert = AlertFeature.error(error.localizedDescription)
                return .none
            case .destination:
                return .none
            case .alert:
                return .none
            }
        }
        .ifLet(\.$destination, action: \.destination)
        .ifLet(\.$alert, action: \.alert)
    }
}

extension InfoListFeature.Destination.State: Equatable {}
extension InfoListFeature.Destination.Action: Equatable {}
