//
//  AdminRegionFeature.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/05/09.
//

import ComposableArchitecture

@Reducer
struct AdminRegionFeature {
    
    @Reducer
    enum Destination {
        case edit(AdminRegionEditFeature)
        case districtInfo(AdminRegionDistrictInfoFeature)
        case districtCreate(AdminRegionDistrictCreateFeature)
    }
    
    @ObservableState
    struct State: Equatable {
        let region: Region
        let districts: [PublicDistrict]
        @Presents var destination: Destination.State?
    }
    
    @CasePathable
    enum Action: Equatable {
        case onEdit
        case onDistrictInfo(PublicDistrict)
        case onDistrictCreate
        case destination(PresentationAction<Destination.Action>)
    }
    
    var body: some ReducerOf<AdminRegionFeature> {
        Reduce { state, action in
            switch action {
            case .onEdit:
                state.destination = .edit(AdminRegionEditFeature.State(item: state.region))
                return .none
            case .onDistrictInfo(let district):
                state.destination = .districtInfo(AdminRegionDistrictInfoFeature.State(district:  district, routes: [RouteSummary.sample]))
                return .none
            case .onDistrictCreate:
                state.destination = .districtCreate(AdminRegionDistrictCreateFeature.State())
                return .none
            case .destination(.presented(let childAction)):
                switch childAction{
                case .edit(.cancelTapped),
                    .districtInfo(.dismissTapped),
                    .districtCreate(.cancelTapped):
                    state.destination = nil
                    return .none
                case .edit,
                    .districtInfo,
                    .districtCreate:
                    return .none
                }
            case .destination(.dismiss):
                state.destination = nil
                return .none
            }
        }
        .ifLet(\.$destination, action: \.destination)
    }
}

extension AdminRegionFeature.Destination.State: Equatable {}
extension AdminRegionFeature.Destination.Action: Equatable {}
