//
//  InfoListFeature.swift
//  MaTool
//
//  Created by 松下和也 on 2025/05/08.
//

import ComposableArchitecture
import Fallback
import Shared

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
        @Shared fileprivate var appState: AppState?

        @Fallback(\InfoListFeature.State.appState?.festivalState.festival)
        @ObservationStateIgnored
        var festival: Festival

        var districts: [District] {
            appState?.festivalState.districts ?? []
        }
        
        var isDismissed: Bool = false
        @Presents var destination: Destination.State? = nil
        @Presents var alert: AlertFeature.State? = nil
        var isLoading: Bool = false
        
        init(_ festival: Festival, appState: Shared<AppState?>) {
            self._appState = appState
            self._festival = festival
        }
    }
    
    @CasePathable
    enum Action: Equatable {
        case festivalTapped
        case districtTapped(District)
        case mapRequested(MapRequest)
        case dismissTapped
        case districtReceived(AppResult<DistrictPack>)
        case destination(PresentationAction<Destination.Action>)
        case alert(PresentationAction<AlertFeature.Action>)
    }
    
    @Dependency(FetchDistrictUseCaseKey.self) var fetchDistrictUseCase
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
                    try await fetchDistrictUseCase(districtId: district.id)
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
            case .districtReceived(.success(let pack)):
                state.destination = .district(DistrictInfoFeature.State(pack, appState: state.$appState))
                state.isLoading = false
                return .none
            case .districtReceived(.failure(let error)):
                state.alert = AlertFeature.error(error.message)
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
                state.alert = AlertFeature.error(error.message)
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
