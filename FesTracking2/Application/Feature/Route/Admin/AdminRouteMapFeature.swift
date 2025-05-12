//
//  Untitled.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/04/05.
//

import ComposableArchitecture
import Foundation

@Reducer
struct AdminRouteMapFeature{
    
    @ObservableState
    struct State: Equatable{
        var route: Route
        var stack: Stack<StackItem> = Stack()
        var errorMessage: String?
        var isUndoAble: Bool { !route.points.isEmpty}
        var isRedoAble: Bool{ !stack.isEmpty }
        @Presents var pointAdmin: AdminPointFeature.State?
        @Presents var segmentAdmin: AdminSegmentFeature.State?
    }
    
    @CasePathable
    enum Action: Equatable{
        case editPoint(Point)
        case mapLongPressed(Coordinate)
        case annotationTapped(Point)
        case polylineTapped(Segment)
        case undoButtonTapped
        case redoButtonTapped
        case doneButtonTapped
        case cancelButtonTapped
        case pointAdmin(PresentationAction<AdminPointFeature.Action>)
        case segmentAdmin(PresentationAction<AdminSegmentFeature.Action>)
    }
    
    var body: some ReducerOf<AdminRouteMapFeature> {
        Reduce{ state, action in
            switch action {
            case .editPoint(let point):
                if let index = state.route.points.firstIndex(where: { $0.id == point.id }) {
                    state.route.points[index] = point
                }
                return .none
            case .mapLongPressed(let coordinate):
                let next = Point(id: UUID().uuidString, coordinate: coordinate, title: nil, description: nil, time: nil, isPassed: false)
                if let last = state.route.points.last{
                    let segment = Segment(id: UUID().uuidString, start: last.coordinate, end: next.coordinate)
                    state.route.segments.append(segment)
                }
                state.route.points.append(next)
                state.stack.clear()
                return .none
            case .annotationTapped(let point):
                state.pointAdmin = AdminPointFeature.State(item: point)
                return .none
            case .polylineTapped(let segment):
                state.segmentAdmin = AdminSegmentFeature.State(item: segment)
                return .none
            case .undoButtonTapped:
                if state.route.points.isEmpty {
                    return .none
                }
                //TODO
                if let point = state.route.points.last,
                   let segment = state.route.segments.last{
                    state.route.points.removeLast()
                    state.route.segments.removeLast()
                    let pair = StackItem(id: UUID(), point: point, segment: segment)
                    state.stack.push(pair)
                }
                return .none
            case .redoButtonTapped:
                if(state.stack.isEmpty){
                    return .none
                }
                if let pair = state.stack.pop(){
                    state.route.points.append(pair.point)
                    state.route.segments.append(pair.segment)
                }
                return .none
            case .doneButtonTapped:
                return .none
            case .cancelButtonTapped:
                return .none
            case .pointAdmin(.presented(.doneButtonTapped)):
                if let pointAdmin = state.pointAdmin,
                   let index = state.route.points.firstIndex(where: { $0.id == pointAdmin.item.id }) {
                    state.route.points[index] = pointAdmin.item
                }
                state.pointAdmin = nil
                return .none
            case .pointAdmin(.presented(.cancelButtonTapped)):
                state.pointAdmin = nil
                return .none
            case .pointAdmin:
                return .none
            case .segmentAdmin(.presented(.saveButtonTapped)):
                if let segmentAdmin = state.segmentAdmin,
                   let index = state.route.segments.firstIndex(where: { $0.id == segmentAdmin.item.id }) {
                    state.route.segments[index] = segmentAdmin.item
                }
                state.segmentAdmin = nil
                return .none
            case .segmentAdmin(.presented(.cancelButtonTapped)):
                state.pointAdmin = nil
                return .none
            case .segmentAdmin:
                return .none
            }
        }
        .ifLet(\.$pointAdmin, action: \.pointAdmin){
            AdminPointFeature()
        }
        .ifLet(\.$segmentAdmin, action: \.segmentAdmin){
            AdminSegmentFeature()
        }
    }
}

struct StackItem: Codable, Equatable{
    let id: UUID
    let point: Point
    let segment: Segment
    static func == (lhs: StackItem, rhs: StackItem) -> Bool {
        return false
    }
}
