//
//  InformationReducer.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/03/02.
//

import Foundation
import ComposableArchitecture
import Dependencies

struct RegionViewerState: Equatable {
    var region: Region
    var districts: [District]
    var isLoading: Bool = false
    var errorMessage: String?
}

enum RegionViewerAction: Equatable {
    case setRegion(Region)
    case fetchDistrictsResponse(Result<[District], RemoteError>)
}

@Reducer
struct RegionViewerFeature{
    
    @Dependency(\.remoteClient) var remoteClient
    
    var body: some Reducer<RegionViewerState, RegionViewerAction> {
        Reduce{state, action in
            switch action {
            case .setRegion(let region):
                state.region = region
                state.isLoading = true
                state.errorMessage = nil
                return .run {[state = state] send in
                    let result = await self.remoteClient.getDistricts(state.region.id)
                    await send(.fetchDistrictsResponse(result))
                }
            case .fetchDistrictsResponse(.success(let districts)):
                state.isLoading = false
                state.districts = districts
                return .none
                
            case .fetchDistrictsResponse(.failure(let error)):
                state.isLoading = false
                state.errorMessage = error.localizedDescription
                return .none
            }
        }
    }
}

