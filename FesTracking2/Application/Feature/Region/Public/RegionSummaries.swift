//
//  RegionSummaries.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/04/02.
//

import ComposableArchitecture

@Reducer
struct RegionSummariesFeature{
    
    @Dependency(\.remoteClient) var remoteClient
    
    @ObservableState
    struct State: Equatable{
        var items: AsyncValue<IdentifiedArrayOf<RegionSummary>> = .loading
        var value:IdentifiedArrayOf<RegionSummary>? {
            return items.value
        }
        var error:Error? {
            return items.error
        }
        var isLoading:Bool {
            return items.isLoading
        }
        @Presents var detailState: RegionDetailFeature.State?
    }
    
    enum Action: Equatable{
        case loaded
        case received(Result<[RegionSummary],RemoteError>)
        case selected(RegionSummary)
    }
    
    var body: some Reducer<State,Action> {
        Reduce{ state, action in
            switch action {
            case .loaded:
                state.items = AsyncValue.loading
                return .run{ send in
                    let item = await self.remoteClient.getRegionSummaries()
                    await send(.received(item))
                }
            case .received(.success(let value)):
                state.items = AsyncValue.success(IdentifiedArray(uniqueElements: value))
                return .none
            case .received(.failure(let error)):
                state.items = AsyncValue.failure(error)
                return .none
            case .selected:
                return .none
            }
        }
    }
}
