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
    enum PointType: Equatable, CaseIterable {
        case checkpoint
        case performance
        case start
        case end
        case rest
        case none
    }
    
    @ObservableState
    struct State: Equatable{
        var point: Point
        var showPopover: Bool = false
        @FetchAll var checkpoints: [Checkpoint]
        @FetchAll var performances: [Performance]
        
        
        var pointType: PointType
        var selectedCheckpoint: Checkpoint?
        var selectedPerformance: Performance?
        var selectedAnchor: Anchor?
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
            case .binding(\.pointType):
                state.point.checkpointId = nil
                state.point.performanceId = nil
                state.point.anchor = nil
                return .none
            case .binding(\.selectedCheckpoint):
                if state.pointType == .checkpoint {
                    state.point.checkpointId = state.selectedCheckpoint?.id
                }
                return .none
            case .binding(\.selectedPerformance):
                if state.pointType == .performance {
                    state.point.performanceId = state.selectedPerformance?.id
                }
                return .none
            case .binding(\.selectedAnchor):
                if state.pointType == .start {
                    state.point.anchor = .start
                } else if state.pointType == .end {
                    state.point.anchor = .end
                } else if state.pointType == .rest {
                    state.point.anchor = .rest
                }
                return .none
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
        self.pointType = .init(point: point)
    }
}

extension AdminPointEdit.PointType {
    init(point: Point){
        if point.checkpointId != nil {
            self = .checkpoint
        } else if point.performanceId != nil {
            self = .performance
        } else if point.anchor == .start {
            self = .start
        } else if point.anchor == .end {
            self = .end
        } else if point.anchor == .rest {
            self = .rest
        } else {
            self = .none
        }
    }
}

