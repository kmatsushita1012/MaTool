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
                switch state.pointType{
                case .start:
                    state.point.anchor = .start
                case .end:
                    state.point.anchor = .end
                case .rest:
                    state.point.anchor = .rest
                default:
                    state.point.anchor = nil
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
        let district = FetchOne(Point
            .join(Route.all) { $0.routeId.eq($1.id) }
            .join(District.all) { $1.districtId.eq($2.id) }
            .select { $2 }).wrappedValue
        self._checkpoints = FetchAll(Checkpoint.where{ $0.festivalId == district?.festivalId })
        self._performances = FetchAll(Performance.where{ $0.districtId == district?.id })
        self.pointType = .init(point: point)
    }
    
    var selectedCheckpoint: Checkpoint? {
        guard case .checkpoint = pointType, let checkpointId = point.checkpointId else {
            return nil
        }
        return checkpoints.first(where: { $0.id == checkpointId })
    }
    
    var selectedPerformance: Performance? {
        guard case .performance = pointType, let performanceId = point.performanceId else {
            return nil
        }
        return performances.first(where: { $0.id == performanceId })
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

