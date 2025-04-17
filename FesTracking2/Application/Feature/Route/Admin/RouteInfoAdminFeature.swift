//
//  RouteInfoAdminFeature.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/04/11.
//

import ComposableArchitecture

@Reducer
struct RouteInfoAdminFeature {
    @ObservableState
    struct State{
        enum Mode {
            case create(id: String)
            case edit(id:String,date:SimpleDate,title:String)
        }
        
        let mode: Mode
        var route: EditableRoute
        var isLoading: Bool = false
        var errorMessage: String? = nil
        @Presents var map: RouteMapAdminFeature.State?
        
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
    enum Action: BindableAction {
        case onAppear
        case getReceived(Result<Route, RemoteError>)
        case binding(BindingAction<State>)
        case mapButtonTapped
        case saveButtonTapped
        case deleteButtonTapped
        case cancelButtonTapped
        case postReceived(Result<String, RemoteError>)
        case map(PresentationAction<RouteMapAdminFeature.Action>)
    }
    
    @Dependency(\.remoteClient) var remoteClient
    @Dependency(\.userDefaultsClient) var userDefaultsClient
    
    var body: some ReducerOf<RouteInfoAdminFeature> {
        BindingReducer()
        Reduce{ state, action in
            switch (action) {
            case .onAppear:
                print("onAppear")
                if case let .edit(id,date,title) = state.mode{
                    print("onAppear edit")
                    print(remoteClient)
                    state.isLoading = true
                    return .run { send in
                        let result = await remoteClient.getRouteDetail(id,date,title)
                        await send(.getReceived(result))
                    }
                }
                return .none
            case .getReceived(.success(let value)):
                state.isLoading = false
                state.route = EditableRoute.init(from: value)
                return .none
            case .getReceived(.failure(let error)):
                state.isLoading = false
                state.errorMessage = error.localizedDescription
                return .none
            case .binding:
                return .none
            case .mapButtonTapped:
                //TODO
                state.map = RouteMapAdminFeature.State(route: state.route)
                return .none
            case .saveButtonTapped:
                guard let accessToken = userDefaultsClient.stringForKey("AccessToken") else {
                    state.errorMessage = "No access token found"
                    return .none
                }
                return .run { [route = state.route] send in
                    let result = await remoteClient.postRoute(route.toRoute(), accessToken)
                    await send(.postReceived(result))
                }
            case .deleteButtonTapped:
                guard let accessToken = userDefaultsClient.stringForKey("AccessToken") else {
                    state.errorMessage = "No access token found"
                    return .none
                }
                let route = state.route
                return .run { send in
                    let result = await remoteClient.deleteRoute(route.districtId,route.date,route.title, accessToken)
                    await send(.postReceived(result))
                }
            case .cancelButtonTapped:
                return .none
            case .postReceived(.success(_)):
                return .none
            case .postReceived(.failure(let error)):
                state.errorMessage = error.localizedDescription
                return .none
            case .map(.presented(.doneButtonTapped)):
                state.map = nil
                return .none
            case .map(.dismiss):
                state.map = nil
                return .none
            case .map:
                return .none
            }
        }
        .ifLet(\.$map, action: \.map){
            RouteMapAdminFeature()
        }
    }
}
