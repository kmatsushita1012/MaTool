//
//  DistrictInfo.swift
//  MaTool
//
//  Created by 松下和也 on 2025/07/27.
//

import ComposableArchitecture
import MapKit

@Reducer
struct DistrictInfo {
    
    @ObservableState
    struct State: Equatable {
        let item: District
        var region: MKCoordinateRegion?
        var isLoading: Bool = false
        var isDismissed:Bool = false
        
        init(item: District){
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
    }
    
    @Dependency(\.dismiss) var dismiss
    
    var body: some ReducerOf<DistrictInfo> {
        BindingReducer()
        Reduce{ state,action in
            switch action {
            case .binding:
                return .none
            case .dismissTapped:
                if #available(iOS 17.0, *) {
                    return .run { _ in
                        await dismiss()
                    }
                } else {
                    state.isDismissed = true
                    return .none
                }
            //　MARK: Homeに移譲
            case .mapTapped:
                state.isLoading = true
                return .none
            }
        }
    }
}
