//
//  RouteSummariesReducer.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/03/02.
//

import ComposableArchitecture
import Foundation
import Dependencies


struct DistrictViewerState: Equatable {
    var district: District
    var summaries: [RouteSummary]
    var isLoading: Bool = false
    var errorMessage: String?
}

enum DistrictViewerAction: Equatable {
    case setDistrict(District)
    case fetchSummmariesResponse(Result<[RouteSummary], RemoteError>)
}

@Reducer
struct DistrictViewerFeature{
    
    @Dependency(\.remoteClient) var remoteClient
    
    var body: some Reducer<DistrictViewerState, DistrictViewerAction> {
        Reduce{state, action in
            switch action {
            case let .setDistrict(district):
                state.district = district
                state.isLoading = true
                state.errorMessage = nil
                return .run {[state = state] send in
                    let result = await self.remoteClient.getRouteSummaries(state.district.id)
                    await send(.fetchSummmariesResponse(result))
                }
            case let .fetchSummmariesResponse(.success(summaries)):
                state.isLoading = false
                state.summaries = summaries
                return .none
                
            case let .fetchSummmariesResponse(.failure(error)):
                state.isLoading = false
                state.errorMessage = error.localizedDescription
                return .none
            }
        }
    }
}


