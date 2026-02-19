//
//  PointEditFeature.swift
//  MaTool
//
//  Created by 松下和也 on 2025/03/06.
//

import ComposableArchitecture
import Shared
import SQLiteData

@Reducer
struct PointEditFeature {
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
        
        @FetchAll var checkpoints: [Checkpoint]
        @FetchAll var performances: [Performance]
        
        var pointType: PointType
        let validTypes: [PointType]
        @Presents var alert: AlertFeature.State?
        
    }
    
    @CasePathable
    enum Action: BindableAction, Equatable {
        case binding(BindingAction<State>)
        case doneTapped
        case moveTapped
        case insertTapped
        case deleteTapped
        case alert(PresentationAction<AlertFeature.Action>)
    }
    
    var body: some ReducerOf<PointEditFeature> {
        BindingReducer()
        Reduce { state, action in
            switch action{
            case .binding(\.pointType):
                state.point.checkpointId = nil
                state.point.performanceId = nil
                switch state.pointType{
                case .checkpoint:
                    state.point.anchor = nil
                    state.point.time = .now
                case .performance:
                    state.point.anchor = nil
                case .start:
                    state.point.anchor = .start
                    state.point.time = .now
                case .end:
                    state.point.anchor = .end
                    state.point.time = .now
                case .rest:
                    state.point.anchor = .rest
                    state.point.time = .now
                case .none:
                    state.point.time = nil
                }
                return .none
            case .doneTapped,
                .moveTapped,
                .insertTapped:
                do {
                    try state.validate()
                } catch  {
                    state.alert = AlertFeature.error(error.localizedDescription)
                }
                return .none
            case .alert:
                state.alert = nil
                return .none
            default:
                return .none
            }
        }
    }
}

extension PointEditFeature.State {
    init(_ point: Point){
        self.point = point
        let district = FetchOne(Point
            .join(Route.all) { $0.routeId.eq($1.id) }
            .join(District.all) { $1.districtId.eq($2.id) }
            .select { $2 }).wrappedValue
        let checkpointQuery = FetchAll(Checkpoint.where{ $0.festivalId == district?.festivalId })
        self._checkpoints = checkpointQuery
        let performanceQuery = FetchAll(Performance.where{ $0.districtId == district?.id })
        self._performances =  performanceQuery
        self.pointType = .init(point: point)
        
        var types: [PointEditFeature.PointType] = [.start, .end, .rest]
        if !checkpointQuery.wrappedValue.isEmpty {
            types.append(.checkpoint)
        }
        if !performanceQuery.wrappedValue.isEmpty {
            types.append(.performance)
        }
        types.append(.none)
        
        self.validTypes = types
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
    
    func validate() throws {
        try point.validate()
        switch pointType {
        case .checkpoint:
            if point.checkpointId == nil {
                throw Point.Error.unknown("重要地点の種類が選択されていません")
            }
        case .performance:
            if point.performanceId == nil {
                throw Point.Error.unknown("余興の種類が選択されていません")
            }
        default:
            return
        }
    }
}

extension PointEditFeature.PointType {
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
