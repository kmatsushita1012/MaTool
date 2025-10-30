//
//  Info.swift
//  MaTool
//
//  Created by 松下和也 on 2025/05/08.
//

import ComposableArchitecture

@Reducer
struct InfoList {
    
    @Reducer
    enum Destination{
        case region(RegionInfo)
        case district(DistrictInfo)
    }
    
    
    @ObservableState
    struct State: Equatable {
        let region: Region
        let districts: [PublicDistrict]
        var isDismissed: Bool = false
        @Presents var destination: Destination.State? = nil
    }
    
    @CasePathable
    enum Action: Equatable {
        case regionTapped
        case districtTapped(PublicDistrict)
        case homeTapped
        case destination(PresentationAction<Destination.Action>)
    }
    
    @Dependency(\.dismiss) var dismiss
    
    var body: some ReducerOf<InfoList> {
        Reduce { state,action in
            switch action {
            case .regionTapped:
                state.destination = .region(RegionInfo.State(item: state.region))
                return .none
            case .districtTapped(let value):
                print(value)
                state.destination = .district(DistrictInfo.State(item: value))
                return .none
            case .homeTapped:
                if #available(iOS 17.0, *) {
                    return .run { _ in
                        await dismiss()
                    }
                } else {
                    state.isDismissed = true
                    return .none
                }
            case .destination(.presented):
                return .none
            case .destination(.dismiss):
                return .none
            }
        }
        .ifLet(\.$destination, action: \.destination)
    }
}

extension InfoList.Destination.State: Equatable {}
extension InfoList.Destination.Action: Equatable {}
