//
//  InformationReducer.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/03/02.
//

import Foundation
import ComposableArchitecture
import Dependencies

struct RegionState: Equatable {
    var region: Region
    var districts: [District]
    var isLoading: Bool = false
    var errorMessage: String?
}

enum RegionAction: Equatable {
    case setRegion(Region)
    case fetchDistrictsResponse(Result<[District], RemoteError>)
}

struct RegionReducer: Reducer{
    
    @Dependency(\.remoteClient) var remoteClient
    
    var body: some Reducer<RegionState, RegionAction> {
        Reduce{state, action in
            switch action {
            case let .setRegion(region):
                state.region = region
                state.isLoading = true
                state.errorMessage = nil
                return .run {[state = state] send in
                    let result = await self.remoteClient.getDistricts(state.region.id)
                    await send(.fetchDistrictsResponse(result))
                }
            case let .fetchDistrictsResponse(.success(districts)):
                state.isLoading = false
                state.districts = districts
                return .none
                
            case let .fetchDistrictsResponse(.failure(error)):
                state.isLoading = false
                state.errorMessage = error.localizedDescription
                return .none
            }
        }
    }
}

