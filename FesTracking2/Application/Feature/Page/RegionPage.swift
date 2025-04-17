//
//  RegionPage.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/04/02.
//

import ComposableArchitecture

@Reducer
struct RegionPageFeature{
    
    @Dependency(\.remoteClient) var remoteClient
    
    @ObservableState
    struct State: Equatable{
        var id: String
        var detail: RegionDetailFeature.State
        var district: DistrictSummariesFeature.State
        @Presents var districtPage: DistrictPageFeature.State?
    }
    
    enum Action: Equatable{
        case loaded
        case detail(RegionDetailFeature.Action)
        case district(DistrictSummariesFeature.Action)
    }
    
    var body: some ReducerOf<RegionPageFeature> {
        Scope(state: \.detail, action: \.detail){ RegionDetailFeature() }
        Scope(state: \.district, action: \.district){ DistrictSummariesFeature() }
        Reduce{ state, action in
            switch action {
            case .loaded:
                return .run { [id = state.id] send in
                    let detailResult = await self.remoteClient.getRegionDetail(id)
                    let districtResult = await self.remoteClient.getDistrictSummaries(id)
                    
                    await send(.detail(.received( detailResult)))
                    await send(.district(.received( districtResult)))
                }
            case .district(.selected(let item)):
                state.districtPage = DistrictPageFeature.State(id:item.id,detail:DistrictDetailFeature.State() ,route: RouteSummariesFeature.State())
                return .none
            default:
                return .none
            }
        }
    }
}

