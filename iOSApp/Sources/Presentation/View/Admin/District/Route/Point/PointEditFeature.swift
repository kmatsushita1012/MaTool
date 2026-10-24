//
//  PointEditFeature.swift
//  MaTool
//
//  Created by 松下和也 on 2025/03/06.
//

import ComposableArchitecture
import Shared

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
        let districtId: District.ID
        @Shared fileprivate var appState: AppState?

        var checkpoints: [Checkpoint] {
            appState?.festivalState.checkpoints ?? []
        }

        var performances: [Performance] {
            guard let districtState = appState?.districtState,
                  districtState.districtId == districtId else { return [] }
            return districtState.performances
        }

        var pointType: PointType
        var validTypes: [PointType] {
            var types: [PointType] = [.start, .end, .rest, .none]
            if !checkpoints.isEmpty || point.checkpointId != nil {
                types.insert(.checkpoint, at: 0)
            }
            if !performances.isEmpty || point.performanceId != nil {
                types.insert(.performance, at: min(1, types.count))
            }
            return types
        }
        @Presents var alert: AlertFeature.State?
        
    }
    
    @CasePathable
    enum Action: BindableAction, Equatable {
        case binding(BindingAction<State>)
        case doneTapped
        case cancelTapped
        case moveTapped
        case insertBeforeTapped
        case insertAfterTapped
        case deleteTapped
        case alert(PresentationAction<AlertFeature.Action>)
    }
    
    var body: some ReducerOf<PointEditFeature> {
        BindingReducer()
        Reduce { state, action in
            switch action{
            case .binding(\.pointType):
                state.point.apply(pointType: state.pointType)
                return .none
            case .doneTapped,
                .moveTapped,
                .insertBeforeTapped,
                .insertAfterTapped:
                do {
                    try state.validate()
                } catch  {
                    state.alert = AlertFeature.error(error.asAppError.message)
                }
                return .none
            case .alert:
                state.alert = nil
                return .none
            case .cancelTapped:
                return .dismiss
            default:
                return .none
            }
        }
    }
}

extension PointEditFeature.State {
    init(_ point: Point, districtId: District.ID, appState: Shared<AppState?>) {
        self.point = point
        self.districtId = districtId
        self._appState = appState
        self.pointType = .init(point: point)
    }
    
    var selectedCheckpoint: Checkpoint? {
        guard case .checkpoint = pointType, let checkpointId = point.checkpointId else {
            return nil
        }
        return appState?.checkpoint(id: checkpointId)
    }
    
    var selectedPerformance: Performance? {
        guard case .performance = pointType, let performanceId = point.performanceId else {
            return nil
        }
        return appState?.performance(id: performanceId, districtId: districtId)
    }
    
    func validate() throws {
        try point.validate()
        switch pointType {
        case .checkpoint:
            if point.checkpointId == nil {
                throw Point.Error.unknown("交差点の種類が選択されていません")
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

fileprivate extension Point {
    /// nil のときだけ現在時刻を入れる
    private mutating func setNowIfTimeNil() {
        if time == nil { time = .now }
    }
    mutating func apply(pointType: PointEditFeature.PointType) {
        checkpointId = nil
        performanceId = nil
        switch pointType {
        case .checkpoint:
            anchor = nil
            setNowIfTimeNil()
        case .performance:
            anchor = nil
        case .start:
            anchor = .start
            setNowIfTimeNil()
        case .end:
            anchor = .end
            setNowIfTimeNil()
        case .rest:
            anchor = .rest
            setNowIfTimeNil()
        case .none:
            anchor = nil
            time = nil
        }
    }
}
