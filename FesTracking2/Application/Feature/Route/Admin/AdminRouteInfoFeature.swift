//
//  AdminRouteInfoFeature.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/04/11.
//

import ComposableArchitecture

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
            case create(id: String)
            case edit(id:String,date:SimpleDate,title:String)
        }
        
        let mode: Mode
        var route: Route
        var isLoading: Bool = false
        var errorMessage: String? = nil
        
        @Presents var destination: Destination.State?
        
        init(mode: Mode){
            self.mode = mode
            switch(mode){
            case let .create(id):
                self.route = .init(districtId: id)
            case let .edit(id,_,_):
                //仮で初期化
                self.isLoading = true
                self.route = .init(districtId: id)
            }
        }
    }
    
    @CasePathable
    enum Action: BindableAction, Equatable {
        case onAppear
        case getReceived(Result<PublicRoute, ApiError>)
        case binding(BindingAction<State>)
        case mapButtonTapped
        case saveButtonTapped
        case cancelButtonTapped
        case exportTapped
        case deleteTapped
        case postReceived(Result<String, ApiError>)
        case deleteReceived(Result<String, ApiError>)
        case destination(PresentationAction<Destination.Action>)
    }
    
    @Dependency(\.apiClient) var apiClient
    @Dependency(\.accessToken) var accessToken
    
    var body: some ReducerOf<AdminRouteInfoFeature> {
        BindingReducer()
        Reduce{ state, action in
            switch (action) {
            case .onAppear:
                if case let .edit(id,date,title) = state.mode{
                    state.isLoading = true
                    return .run { send in
                        let result = await apiClient.getRoute(id,date,title, accessToken.value)
                        await send(.getReceived(result))
                    }
                }
                return .none
            case .getReceived(.success(let value)):
                state.isLoading = false
                state.route = value.toModel()
                return .none
            case .getReceived(.failure(let error)):
                state.isLoading = false
                state.errorMessage = error.localizedDescription
                return .none
            case .binding:
                return .none
            case .mapButtonTapped:
                //TODO
                state.destination = .map(AdminRouteMapFeature.State(route: state.route))
                return .none
            case .saveButtonTapped:
                if state.route.title.isEmpty {
                    state.errorMessage = "タイトルには1文字以上を設定してください。"
                    return .none
                }
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
            case .cancelButtonTapped:
                return .none
            case .exportTapped:
                state.destination = .export(AdminRouteExportFeature.State(route: state.route))
                return .none
            case .deleteTapped:
                return .run { [route = state.route] send in
                    //TODO
                    guard let token = accessToken.value else {
                        await send(.postReceived(.failure(.unknown("No Access Token"))))
                        return
                    }
                    let result = await apiClient.deleteRoute(route.districtId, route.date, route.title, token)
                    await send(.postReceived(result))
                }
            case .postReceived(.success(_)):
                return .none
            case .postReceived(.failure(let error)):
                state.errorMessage = error.localizedDescription
                return .none
            case .deleteReceived(.success(_)):
                return .none
            case .deleteReceived(.failure(let error)):
                state.errorMessage = error.localizedDescription
                return .none
            case .destination(.presented(let childAction)):
                switch childAction {
                case .map(.doneButtonTapped):
                    if case let .map(mapState) = state.destination{
                        state.route = mapState.route
                    }
                    state.destination = nil
                    return .none
                case .map(.cancelButtonTapped),
                    .export(.dismissTapped):
                    state.destination = nil
                    return .none
                case .map,.export:
                    return .none
                }
            case .destination(.dismiss):
                state.destination = nil
                return .none
            }
        }
        .ifLet(\.$destination, action: \.destination)
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

