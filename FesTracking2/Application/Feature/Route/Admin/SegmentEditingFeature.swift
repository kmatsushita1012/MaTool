//
//  SegmentAdminReducer.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/03/06.
//
import ComposableArchitecture


@Reducer
struct SegmentAdminFeature{
    @Dependency(\.remoteClient) var remoteClient
    @ObservableState
    struct State: Equatable{
        var item: Segment
        var isLoading: Bool = false
        var errorMessage: String?
    }

    enum Action: Equatable{
        case switchCurve(Bool)
        case received(Result<[Coordinate],RemoteError>)
        case saveButtonTapped
        case cancelButtonTapped
    }
    
    var body:some ReducerOf<SegmentAdminFeature>{
        Reduce{ state, action in
            switch action{
            case .switchCurve(let value):
                let start = state.item.start
                let end = state.item.end
                if(value){
                    state.errorMessage = nil
                    state.isLoading = true
                    return .run {[] send in
                        let result = await self.remoteClient.getSegmentCoordinate(start, end)
                        await send(.received(result))
                    }
                }else{
                    state.item.coordinates = [start, end]
                    return .none
                }
            case .received(.success(let coordinates)):
                state.isLoading = false
                state.item.coordinates = coordinates
                return .none
            case .received(.failure(let error)):
                state.isLoading = false
                state.errorMessage = error.localizedDescription
                return .none
            case .saveButtonTapped:
                return .none
            case .cancelButtonTapped:
                return .none
            }
        
        }
    }
}
