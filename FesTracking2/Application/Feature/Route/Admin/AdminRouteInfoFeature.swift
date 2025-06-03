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
        case export(AdminRouteExportFeature)
    }
    
    @ObservableState
    struct State: Equatable{
        enum Mode:Equatable {
            case create(districtId: String)
            case edit(id: String)
        }
        
        let mode: Mode
        var route: Route
        var isLoading: Bool = false
        let performances: [Performance]
        @Presents var destination: Destination.State?
        @Presents var alert: OkAlert.State?
        
        init(mode: Mode, performances: [Performance]){
            self.mode = mode
            self.performances = performances
            switch(mode){
            case let .create(id):
                self.route = .init(id: UUID().uuidString, districtId: id)
            case let .edit(id):
                //仮で初期化
                self.isLoading = true
                self.route = .init(id: UUID().uuidString, districtId: id)
            }
        }
    }
    
    @CasePathable
    enum Action: BindableAction, Equatable {
        case onAppear
        case binding(BindingAction<State>)
        case mapTapped
        case saveTapped
        case cancelTapped
        case exportTapped
        case deleteTapped
        case getReceived(Result<PublicRoute, ApiError>)
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
            case .onAppear:
                if case let .edit(id) = state.mode{
                    state.isLoading = true
                    return .run { send in
                        let result = await apiClient.getRoute(id, accessToken.value)
                        await send(.getReceived(result))
                    }
                }
                return .none
            case .binding:
                return .none
            case .mapTapped:
                //TODO 余興情報渡し
                state.destination = .map(AdminRouteMapFeature.State(route: state.route, performances: state.performances))
                return .none
            case .saveTapped:
                if state.route.title.isEmpty {
                    state.alert = OkAlert.make("タイトルは1文字以上を指定してください。")
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
            case .exportTapped:
                state.destination = .export(AdminRouteExportFeature.State(route: state.route))
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
            case .getReceived(let result):
                state.isLoading = false
                switch result {
                case .success(let value):
                    state.route = value.toModel()
                case .failure(let error):
                    state.alert = OkAlert.make("情報の取得に失敗しました。 \(error.localizedDescription)")
                }
                return .none
            case .postReceived(let result):
                state.isLoading = false
                if case let .failure(error) = result {
                    state.alert = OkAlert.make("情報の取得に失敗しました。 \(error.localizedDescription)")
                }
                return .none
            case .deleteReceived(let result):
                state.isLoading = false
                if case let .failure(error) = result {
                    state.alert = OkAlert.make("情報の取得に失敗しました。 \(error.localizedDescription)")
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
                case .map(.cancelTapped),
                    .export(.dismissTapped):
                    state.destination = nil
                    return .none
                case .map,.export:
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

