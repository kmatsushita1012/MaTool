//
//  DistrictSummaries.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/04/02.
//

import ComposableArchitecture

@Reducer
struct DistrictSummariesFeature{
    
    @Dependency(\.apiClient) var apiClient
    
    @ObservableState
    struct State: Equatable{
        var items: AsyncValue<IdentifiedArrayOf<DistrictSummary>> = .loading
        var value:IdentifiedArrayOf<DistrictSummary>? {
            return items.value
        }
        var error:Error? {
            return items.error
        }
        var isLoading:Bool {
            return items.isLoading
        }
        @Presents var detailState: DistrictDetailFeature.State?
    }
    
    enum Action: Equatable{
        case loaded(String)
        case received(Result<[DistrictSummary],ApiError>)
        case selected(DistrictSummary)
    }
    
    var body: some ReducerOf<DistrictSummariesFeature> {
        Reduce{ state, action in
            switch action {
            case .loaded(let id):
                state.items = AsyncValue.loading
                return .run{ send in
                    let item = await self.apiClient.getDistrictSummaries(id)
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
