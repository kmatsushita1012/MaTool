//
//  RouteDetail.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/04/02.
//
import ComposableArchitecture

@Reducer
struct RouteDetailFeature{
    
    @Dependency(\.remoteClient) var remoteClient
    
    @ObservableState
    struct State: Equatable{
        var item: AsyncValue<Route> = .loading
        var value:Route? {
            return item.value
        }
        var error:Error? {
            return item.error
        }
        var isLoading:Bool {
            return item.isLoading
        }
    }
    
    enum Action: Equatable{
        case loaded(String)
        case received(Result<Route,RemoteError>)
    }
    
    var body: some ReducerOf<RouteDetailFeature> {
        Reduce{ state, action in
            switch action {
            case .loaded(let id):
                state.item = AsyncValue.loading
                return .run{ send in
                    let item = await self.remoteClient.getRouteDetail(id,nil,nil)
                    await send(.received(item))
                }
            case .received(.success(let value)):
                state.item = AsyncValue.success(value)
                return .none
            case .received(.failure(let error)):
                state.item = AsyncValue.failure(error)
                return .none
            }
        }
    }
}
