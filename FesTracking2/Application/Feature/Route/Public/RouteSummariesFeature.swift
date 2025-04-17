//
//  RouteSummaries.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/04/02.
//

import ComposableArchitecture

@Reducer
struct RouteSummariesFeature{
    
    @Dependency(\.remoteClient) var remoteClient
    
    @ObservableState
    struct State: Equatable{
        var items: AsyncValue<IdentifiedArrayOf<RouteSummary>> = .loading
        var value:IdentifiedArrayOf<RouteSummary>? {
            return items.value
        }
        var error:Error? {
            return items.error
        }
        var isLoading:Bool {
            return items.isLoading
        }
        @Presents var detailState: RouteDetailFeature.State?
    }
    
    enum Action: Equatable{
        case loaded(String)
        case received(Result<[RouteSummary],RemoteError>)
        case selected(RouteSummary)
    }
    
    var body: some ReducerOf<RouteSummariesFeature> {
        Reduce{ state, action in
            switch action {
            case .loaded(let id):
                state.items = AsyncValue.loading
                return .run{ send in
                    let item = await self.remoteClient.getRouteSummaries(id)
                    await send(.received(item))
                }
            case .received(.success(let value)):
                state.items = AsyncValue.success(IdentifiedArray(uniqueElements: value))
                return .none
            case .received(.failure(let error)):
                state.items = AsyncValue.failure(error)
                return .none
            case .selected(_):
                return .none
            }
            
        }
    }
}
