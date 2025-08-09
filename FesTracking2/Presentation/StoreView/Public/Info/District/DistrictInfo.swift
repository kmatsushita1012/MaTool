//
//  DistrictInfo.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/07/27.
//

import ComposableArchitecture
import MapKit

@Reducer
struct DistrictInfo {
    
    @ObservableState
    struct State: Equatable {
        let item: PublicDistrict
        var region: MKCoordinateRegion?
        
        init(item: PublicDistrict){
            self.item = item
            if let base = item.base, item.area.isEmpty{
                region = makeRegion(origin: base, spanDelta: spanDelta)
            }else{
                region = makeRegion(item.area)
            }
        }
    }
    
    @CasePathable
    enum Action: Equatable, BindableAction {
        case binding(BindingAction<State>)
        case dismissTapped
        case mapTapped
        case showMap(PublicMap.Content)
    }
    
    @Dependency(\.dismiss) var dismiss
    
    var body: some ReducerOf<DistrictInfo> {
        BindingReducer()
        Reduce{ state,action in
            switch action {
            case .binding:
                return .none
            case .dismissTapped:
                return .run { _ in
                    await dismiss()
                }
            case .mapTapped:
                return .run { [item = state.item] send in
                    await send(.showMap(.route(item)))
                }
            case .showMap:
                return .none
            }
        }
    }
}
