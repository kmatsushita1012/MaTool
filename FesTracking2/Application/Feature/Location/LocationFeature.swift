//
//  LocationFeature.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/04/05.
//

import ComposableArchitecture

@Reducer
struct LocationFeature{
    
    @ObservableState
    struct State:Equatable{
        var item: AsyncValue<Location>  = .loading
        var value:Location? {
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
        case received(Result<Location,RemoteError>)
    }
    
    @Dependency(\.remoteClient) var remoteClient
    
    var body: some ReducerOf<LocationFeature> {
        Reduce{state, action in
            switch action{
            case .loaded(let id):
                state.item = .loading
                return .run{ send in
                    let item = await self.remoteClient.getLocation(id)
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
