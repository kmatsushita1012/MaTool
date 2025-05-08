//
//  DistrictDetail.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/04/02.
//
import ComposableArchitecture

@Reducer
struct DistrictDetailFeature{
    
    @Dependency(\.apiClient) var apiClient
    
    @ObservableState
    struct State: Equatable{
        var item: AsyncValue<PublicDistrict> = .loading
        var value:PublicDistrict? {
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
        case received(Result<PublicDistrict,ApiError>)
    }
    
    var body: some Reducer<State,Action> {
        Reduce{ state, action in
            switch action {
            case .loaded(let id):
                state.item = .loading
                return .run{ send in
                    let item = await self.apiClient.getDistrict(id)
                    await send(.received(item))
                }
            case .received(.success(let value)):
                state.item = .success(value)
                return .none
            case .received(.failure(let error)):
                state.item = .failure(error)
                return .none
            }
        }
    }
}
