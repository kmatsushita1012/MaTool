//
//  AdminRouteInfoFeature.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/04/11.
//

import ComposableArchitecture

@Reducer
struct AdminRouteInfoFeature {
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
        @Presents var map: AdminRouteMapFeature.State?
        
        init(mode: Mode){
            self.mode = mode
            switch(mode){
            case let .create(id):
                self.route = .init(districtId: id)
            case let .edit(id,_,_):
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
        case postReceived(Result<String, ApiError>)
        case map(PresentationAction<AdminRouteMapFeature.Action>)
    }
    
    @Dependency(\.apiClient) var apiClient
    @Dependency(\.userDefaultsClient) var userDefaultsClient
    
    var body: some ReducerOf<AdminRouteInfoFeature> {
        BindingReducer()
        Reduce{ state, action in
            print("routeinfo \(state.map)")
            switch (action) {
            case .onAppear:
                if case let .edit(id,date,title) = state.mode{
                    state.isLoading = true
                    return .run { send in
                        let result = await apiClient.getRoute(id,date,title)
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
                state.map = AdminRouteMapFeature.State(route: state.route)
                return .none
            case .saveButtonTapped:
                guard let accessToken = userDefaultsClient.stringForKey("AccessToken") else {
                    state.errorMessage = "No access token found"
                    return .none
                }
                switch state.mode {
                case .create:
                    return .run { [route = state.route] send in
                        let result = await apiClient.postRoute(route, accessToken)
                        await send(.postReceived(result))
                    }
                case .edit:
                    return .run { [route = state.route] send in
                        let result = await apiClient.putRoute(route, accessToken)
                        await send(.postReceived(result))
                    }
                }
            case .cancelButtonTapped:
                return .none
            case .postReceived(.success(_)):
                return .none
            case .postReceived(.failure(let error)):
                state.errorMessage = error.localizedDescription
                return .none
            case .map(.presented(.doneButtonTapped)):
                if let route = state.map?.route{
                    state.route = route
                }
                state.map = nil
                return .none
            case .map(.presented(.cancelButtonTapped)):
                state.map = nil
                return .none
            case .map:
                return .none
            }
        }
        .ifLet(\.$map, action: \.map){
            AdminRouteMapFeature()
        }
    }
}
//
//case .deleteButtonTapped:
//    guard let accessToken = userDefaultsClient.stringForKey("AccessToken") else {
//        state.errorMessage = "No access token found"
//        return .none
//    }
//    let route = state.route
//    return .run { send in
//        let result = await apiClient.deleteRoute(route.districtId,route.date,route.title, accessToken)
//        await send(.postReceived(result))
//    }
