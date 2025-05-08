//
//  RegionSummaries.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/04/02.
//

import ComposableArchitecture

@Reducer
struct RegionSummariesFeature{
    
    @Dependency(\.apiClient) var apiClient
    
    @ObservableState
    struct State: Equatable{
        var items: AsyncValue<[Region]> = .loading
        var value:[Region]? {
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
        case received(Result<[Region],ApiError>)
        case selected(Region)
    }
    
    var body: some Reducer<State,Action> {
        Reduce{ state, action in
            switch action {
            case .loaded:
                state.items = AsyncValue.loading
                return .run{ send in
                    let item = await self.apiClient.getRegions()
                    await send(.received(item))
                }
            case .received(.success(let value)):
                state.items = .success(value)
                return .none
            case .received(.failure(let error)):
                state.items = .failure(error)
                return .none
            case .selected:
                return .none
            }
        }
    }
}
