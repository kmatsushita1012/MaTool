//
//  PointAdmin.swift
//  MaTool
//
//  Created by 松下和也 on 2025/03/06.
//

import ComposableArchitecture
import Shared
import Foundation

@Reducer
struct AdminPointEdit{

    @ObservableState
    struct State: Equatable{
        let id: String
        var type: PointType
        var coordinate: Coordinate
        var time: SimpleTime?
        var selectedCheckpoint: Checkpoint?
        let checkpoints: [Checkpoint]
        var selectedPerformance: Performance?
        let performances: [Performance]
        @Presents var alert: Alert.State?
    }
    
    @CasePathable
    enum Action: BindableAction, Equatable {
        case binding(BindingAction<State>)
        case doneTapped
        case moveTapped
        case insertTapped
        case deleteTapped
        case alert(PresentationAction<Alert.Action>)
    }
    
    var body: some ReducerOf<AdminPointEdit> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            default:
                return .none
            }
        
        }
    }
}

extension AdminPointEdit.State {
    init (_ point: Point, checkpoints: [Checkpoint], performances: [Performance]){
        self.id = point.id
        self.type = .from(point)
        self.coordinate = point.coordinate
        self.time = point.time
        self.checkpoints = checkpoints
        self.performances = performances
    }
    
    init (coordinate: Coordinate, checkpoints: [Checkpoint], performances: [Performance]){
        self.id = UUID().uuidString
        self.type = .waypoint
        self.coordinate = coordinate
        self.time = .now
        self.checkpoints = checkpoints
        self.performances = performances
    }
    
}

extension AdminPointEdit {
    private func buildPoint(from state: State) throws -> Point{
        switch state.type{
        case .checkpoint:
            try buildCheckpoint(from: state)
        case .performance:
            try buildPerformance(from: state)
        case .start:
            try buildAnchor(from: state, role: .start)
        case .end:
            try buildAnchor(from: state, role: .end)
        case .rest:
            try buildAnchor(from: state, role: .rest)
        case .waypoint:
            .waypoint(.init(id: state.id, coordinate: state.coordinate))
        }
    }
    
    private func buildCheckpoint(from state: State) throws -> Point {
        guard let time = state.time else {
            throw PointBuildError.time
        }
        guard let checkpoint = state.selectedCheckpoint else {
            throw PointBuildError.checkpoint
        }
        return .checkpoint(.init(id: state.id, coordinate: state.coordinate, time: time, checkpointId: checkpoint.id))
    }
    
    private func buildPerformance(from state: State) throws -> Point {
        guard let performance = state.selectedPerformance else {
            throw PointBuildError.performance
        }
        return .performance(.init(id: state.id, coordinate: state.coordinate, time: state.time, performanceId: performance.id))
    }
    
    private func buildAnchor(from state: State, role: Point.Anchor.Role) throws -> Point {
        guard let time = state.time else {
            throw PointBuildError.time
        }
        return .anchor(.init(id: state.id, coordinate: state.coordinate, time: time, role: role))
    }
}


enum PointBuildError: Error {
    case time
    case checkpoint
    case performance
    
    var localizedDescription: String {
        switch self {
        case .time:
            return "時刻が設定されていません。"
        case .checkpoint:
            return "重要地点が設定されていません。"
        case .performance:
            return "余興が設定されていません。"
        }
    }
}
