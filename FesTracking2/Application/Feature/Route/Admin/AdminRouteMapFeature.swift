//
//  Untitled.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/04/05.
//

import ComposableArchitecture
import Foundation
import MapKit

@Reducer
struct AdminRouteMapFeature{
    
    @ObservableState
    struct State: Equatable{
        var route: Route
        var stack: Stack<StackItem> = Stack()
        var isUndoable: Bool { !route.points.isEmpty}
        var isRedoable: Bool{ !stack.isEmpty }
        let performances: [Performance]
        var region: MKCoordinateRegion?
        @Presents var pointAdmin: AdminPointFeature.State?
        @Presents var segmentAdmin: AdminSegmentFeature.State?
        @Presents var alert: OkAlert.State?
        
        init(route:Route, performances: [Performance], base: Coordinate?){
            self.route = route
            self.performances = performances
            if let base = base{
                self.region = MKCoordinateRegion(
                    center: base.toCL(),
                    span: MKCoordinateSpan(latitudeDelta: spanDelta, longitudeDelta: spanDelta)
                )
            }
        }
    }
    
    @CasePathable
    enum Action: Equatable, BindableAction{
        case binding(BindingAction<State>)
        case editPoint(Point)
        case mapLongPressed(Coordinate)
        case annotationTapped(Point)
        case polylineTapped(Segment)
        case undoTapped
        case redoTapped
        case doneTapped
        case cancelTapped
        case pointAdmin(PresentationAction<AdminPointFeature.Action>)
        case segmentAdmin(PresentationAction<AdminSegmentFeature.Action>)
        case alert(PresentationAction<OkAlert.Action>)
    }
    
    var body: some ReducerOf<AdminRouteMapFeature> {
        BindingReducer()
        Reduce{ state, action in
            switch action {
            case .binding:
                return .none
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
                state.pointAdmin = AdminPointFeature.State(item: point, performances: state.performances)
                return .none
            case .polylineTapped(let segment):
                state.segmentAdmin = AdminSegmentFeature.State(item: segment)
                return .none
            case .undoTapped:
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
            case .redoTapped:
                if(state.stack.isEmpty){
                    return .none
                }
                if let pair = state.stack.pop(){
                    state.route.points.append(pair.point)
                    state.route.segments.append(pair.segment)
                }
                return .none
            case .doneTapped:
                return .none
            case .cancelTapped:
                return .none
            case .pointAdmin(.presented(.doneTapped)):
                if let pointAdmin = state.pointAdmin,
                   let index = state.route.points.firstIndex(where: { $0.id == pointAdmin.item.id }) {
                    state.route.points[index] = pointAdmin.item
                }
                state.pointAdmin = nil
                return .none
            case .pointAdmin(.presented(.cancelTapped)):
                state.pointAdmin = nil
                return .none
            case .pointAdmin:
                return .none
            case .segmentAdmin(.presented(.saveTapped)):
                if let segmentAdmin = state.segmentAdmin,
                   let index = state.route.segments.firstIndex(where: { $0.id == segmentAdmin.item.id }) {
                    state.route.segments[index] = segmentAdmin.item
                }
                state.segmentAdmin = nil
                return .none
            case .segmentAdmin(.presented(.cancelTapped)):
                state.pointAdmin = nil
                return .none
            case .segmentAdmin:
                return .none
            case .alert(.presented(.okTapped)):
                state.alert = nil
                return .none
            case .alert:
                return .none
            }
        }
        .ifLet(\.$pointAdmin, action: \.pointAdmin){
            AdminPointFeature()
        }
        .ifLet(\.$segmentAdmin, action: \.segmentAdmin){
            AdminSegmentFeature()
        }
        .ifLet(\.alert, action: \.alert)
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
