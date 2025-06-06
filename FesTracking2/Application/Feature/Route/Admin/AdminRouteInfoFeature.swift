//
//  AdminRouteInfoFeature.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/04/11.
//

import ComposableArchitecture
import Foundation

@Reducer
struct AdminRouteInfoFeature {
    
    @Reducer
    enum Destination {
        case map(AdminRouteMapFeature)
    }
    
    @ObservableState
    struct State: Equatable{
        enum Mode:Equatable {
            case create(String,Span)
            case edit(Route)
        }
        
        let mode: Mode
        var route: Route
        var isLoading: Bool = false
        let performances: [Performance]
        let base: Coordinate?
        @Presents var destination: Destination.State?
        @Presents var alert: OkAlert.State?
        
        init(mode: Mode, performances: [Performance], base: Coordinate?){
            self.mode = mode
            self.performances = performances
            self.base = base
            switch(mode){
            case let .create(id, span):
                self.route = .init(
                    id: UUID().uuidString,
                    districtId: id,
                    date: SimpleDate.fromDate(span.start),
                    start: SimpleTime.fromDate(span.start),
                    goal: SimpleTime.fromDate(span.end)
                )
            case let .edit(route):
                self.route = route
            }
        }
    }
    
    @CasePathable
    enum Action: BindableAction, Equatable {
        case binding(BindingAction<State>)
        case mapTapped
        case saveTapped
        case cancelTapped
        case deleteTapped
        case postReceived(Result<String, ApiError>)
        case deleteReceived(Result<String, ApiError>)
        case destination(PresentationAction<Destination.Action>)
        case alert(PresentationAction<OkAlert.Action>)
        
    }
    
    @Dependency(\.apiClient) var apiClient
    @Dependency(\.accessToken) var accessToken
    
    var body: some ReducerOf<AdminRouteInfoFeature> {
        BindingReducer()
        Reduce{ state, action in
            switch (action) {
            case .binding:
                return .none
            case .mapTapped:
                //TODO 余興情報渡し
                state.destination = .map(AdminRouteMapFeature.State(route: state.route, performances: state.performances, base: state.base))
                return .none
            case .saveTapped:
                if state.route.title.isEmpty {
                    state.alert = OkAlert.error("タイトルは1文字以上を指定してください。")
                    return .none
                } else if state.route.title.contains("/") {
                    state.alert = OkAlert.error("タイトルに\"/\"を含むことはできません")
                    return .none
                }
                state.isLoading = true
                switch state.mode {
                case .create:
                    return .run { [route = state.route] send in
                        if let token = accessToken.value{
                            let result = await apiClient.postRoute(route, token)
                            await send(.postReceived(result))
                        }else{
                            await send(.postReceived(.failure(.unknown("No Access Token"))))
                        }
                    }
                case .edit:
                    return .run { [route = state.route] send in
                        if let token = accessToken.value{
                            let result = await apiClient.putRoute(route, token)
                            await send(.postReceived(result))
                        }else{
                            await send(.postReceived(.failure(.unknown("No Access Token"))))
                        }
                    }
                }
            case .cancelTapped:
                return .none
            case .deleteTapped:
                state.isLoading = true
                return .run { [route = state.route] send in
                    //TODO
                    guard let token = accessToken.value else {
                        await send(.postReceived(.failure(.unknown("No Access Token"))))
                        return
                    }
                    let result = await apiClient.deleteRoute(route.id, token)
                    await send(.postReceived(result))
                }
            case .postReceived(let result):
                state.isLoading = false
                if case let .failure(error) = result {
                    state.alert = OkAlert.error("情報の取得に失敗しました。 \(error.localizedDescription)")
                }
                return .none
            case .deleteReceived(let result):
                state.isLoading = false
                if case let .failure(error) = result {
                    state.alert = OkAlert.error("情報の取得に失敗しました。 \(error.localizedDescription)")
                }
                return .none
            case .destination(.presented(let childAction)):
                switch childAction {
                case .map(.doneTapped):
                    if case let .map(mapState) = state.destination{
                        state.route = mapState.route
                    }
                    state.destination = nil
                    return .none
                case .map(.cancelTapped):
                    state.destination = nil
                    return .none
                case .map:
                    return .none
                }
            case .destination(.dismiss):
                state.destination = nil
                return .none
            case .alert(.presented(.okTapped)):
                state.alert = nil
                return .none
            case .alert(_):
                return .none
            }
        }
        .ifLet(\.$destination, action: \.destination)
        .ifLet(\.$alert, action: \.alert)
    }
}

extension AdminRouteInfoFeature.Destination.State: Equatable {}
extension AdminRouteInfoFeature.Destination.Action: Equatable {}
extension AdminRouteInfoFeature.State.Mode {
    var isCreate: Bool {
        if case .create = self {
            return true
        }
        return false
    }
}

