//
//  DistrictSummaries.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/04/02.
//

import ComposableArchitecture

@Reducer
struct DistrictListFeature{
    
    @Dependency(\.apiClient) var apiClient
    
    @ObservableState
    struct State: Equatable{
        var items: AsyncValue<[PublicDistrict]> = .loading
        var value:[PublicDistrict]? {
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
        case received(Result<[PublicDistrict],ApiError>)
        case selected(PublicDistrict)
    }
    
    var body: some ReducerOf<DistrictListFeature> {
        Reduce{ state, action in
            switch action {
            case .loaded(let id):
                state.items = .loading
                return .run{ send in
                    let item = await self.apiClient.getDistricts(id)
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
