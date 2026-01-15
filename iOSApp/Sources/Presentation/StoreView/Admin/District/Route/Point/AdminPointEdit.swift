//
//  PointAdmin.swift
//  MaTool
//
//  Created by 松下和也 on 2025/03/06.
//

import ComposableArchitecture
import Shared
import SQLiteData

@Reducer
struct AdminPointEdit{
    
    @ObservableState
    struct State: Equatable{
        var point: Point
        var showPopover: Bool = false
        @FetchAll var checkpoints: [Checkpoint]
        @FetchAll var performances: [Performance]
    }
    
    @CasePathable
    enum Action: BindableAction, Equatable {
        case binding(BindingAction<State>)
        case doneTapped
        case moveTapped
        case insertTapped
        case deleteTapped
        case titleFieldFocused
        case titleOptionSelected(Checkpoint)
    }
    
    var body: some ReducerOf<AdminPointEdit> {
        BindingReducer()
        Reduce { state, action in
            switch action{
            case .binding:
                return .none
            case .doneTapped:
                return .none
            case .moveTapped:
               return .none
           case .insertTapped:
               return .none
           case .deleteTapped:
               return .none
            case .titleFieldFocused:
                state.showPopover = true
                return .none
            case .titleOptionSelected(let option):
                state.showPopover = false
                return .none
            }
        
        }
    }
}

extension AdminPointEdit.State {
    init(_ point: Point){
        self.point = point
        let checkpointsQuery = Point
            .join(Route.all) { $0.routeId.eq($1.id) }
            .join(District.all) { $1.districtId.eq($2.id) }
            .join(Checkpoint.all) { $2.festivalId.eq($3.festivalId) }
            .select { $3  }
        self._checkpoints = FetchAll(checkpointsQuery)
        let performancesQuery = Point
            .join(Route.all) { $0.routeId.eq($1.id) }
            .join(Performance.all) { $1.districtId.eq($2.id) }
            .select { $2  }
        self._performances = FetchAll(performancesQuery)
    }
}
