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
struct AdminRouteMap{
    
    @Reducer
    enum Destination {
        case point(AdminPointEdit)
        case segment(AdminSegmentFeature)
    }
    
    enum Operation: Equatable{
        case add
        case move(Int)
        case insert(Int)
    }
    
    @ObservableState
    struct State: Equatable{
        var manager: EditManager<Route>
        var operation: Operation = .add
        let milestones: [Information]
        var region: MKCoordinateRegion?
        @Presents var destination: Destination.State?
        @Presents var alert: Alert.State?
        var canUndo: Bool { manager.canUndo }
        var canRedo: Bool{ manager.canRedo }
        var route: Route {
            manager.value
        }
        
        
        init(route: Route, milestones: [Information], origin: Coordinate){
            self.manager = EditManager(route)
            self.milestones = milestones
            if !route.points.isEmpty{
                self.region = makeRegion(route.points.map{ $0.coordinate })
            }else{
                self.region = makeRegion(origin: origin, spanDelta: spanDelta)
            }
        }
    }
    
    @CasePathable
    enum Action: Equatable, BindableAction{
        case binding(BindingAction<State>)
        case mapLongPressed(Coordinate)
        case annotationTapped(Point)
        case polylineTapped(Segment)
        case undoTapped
        case redoTapped
        case doneTapped
        case cancelTapped
        case destination(PresentationAction<Destination.Action>)
        case alert(PresentationAction<Alert.Action>)
    }
    
    var body: some ReducerOf<AdminRouteMap> {
        BindingReducer()
        Reduce{ state, action in
            switch action {
            case .binding:
                return .none
            case .mapLongPressed(let coordinate):
                switch state.operation {
                case .add:
                    let point = Point(id: UUID().uuidString, coordinate: coordinate, title: nil, description: nil, time: nil, isPassed: false)
                    state.manager.apply{
                        guard let last = $0.points.last else {
                            $0.points.append(point)
                            return
                        }
                        $0.points.append(point)
                        let segment = Segment(id: UUID().uuidString, start: last.coordinate, end: coordinate)
                        $0.segments.append(segment)
                    }
                    return .none
                case .move(let index):
                    if index < 0 || index >= state.route.points.count { return .none }
                    state.manager.apply{
                        $0.points[index].coordinate = coordinate
                        if index > 0 {
                            $0.segments[index-1] = Segment(id: UUID().uuidString, start: $0.points[index-1].coordinate, end: coordinate)
                        }
                        if index < $0.segments.count{
                            $0.segments[index] = Segment(id: UUID().uuidString, start: coordinate, end: $0.points[index+1].coordinate)
                        }
                    }
                    state.operation = .add
                    return .none
                case .insert(let index):
                    if index < 0 || index >= state.route.points.count { return .none }
                    let point = Point(id: UUID().uuidString, coordinate: coordinate)
                    state.manager.apply{
                        if index > 0 {
                            let segment = Segment(id: UUID().uuidString, start: $0.points[index-1].coordinate, end: coordinate)
                            $0.segments[index-1] = segment
                        }
                        let segment = Segment(id: UUID().uuidString, start: coordinate, end: $0.points[index].coordinate)
                        if index < $0.segments.count {
                            $0.segments.insert(segment, at: index)
                        }else{
                            $0.segments.append(segment)
                        }
                        $0.points.insert(point, at: index)
                    }
                    state.operation = .add
                    return .none
                }
            case .annotationTapped(let point):
                state.destination = .point(
                    AdminPointEdit.State(item: point, milestones: state.milestones))
                state.operation = .add
                return .none
            case .polylineTapped(let segment):
                state.destination = .segment(AdminSegmentFeature.State(item: segment))
                state.operation = .add
                return .none
            case .undoTapped:
                state.manager.undo()
                state.operation = .add
                return .none
            case .redoTapped:
                state.manager.redo()
                state.operation = .add
                return .none
            case .doneTapped:
                return .none
            case .cancelTapped:
                return .none
            case .destination(.presented(let childAction)):
                switch childAction {
                case .point(.moveTapped):
                    if case let .point(pointState) = state.destination,
                       let index = state.route.points.firstIndex(where: { $0.id == pointState.item.id }){
                        state.manager.apply {
                            $0.points[index] = pointState.item
                        }
                        state.operation = .move(index)
                    }
                    state.destination = nil
                    return .none
                case .point(.insertTapped):
                    if case let .point(pointState) = state.destination,
                       let index = state.route.points.firstIndex(where: { $0.id == pointState.item.id }){
                        state.manager.apply {
                            $0.points[index] = pointState.item
                        }
                        state.operation = .insert(index)
                    }
                    state.destination = nil
                    return .none
                case .point(.deleteTapped):
                    if case let .point(pointState) = state.destination,
                       let index = state.route.points.firstIndex(where: { $0.id == pointState.item.id }){
                        state.manager.apply {
                            if index < $0.segments.count {
                                $0.segments.remove(at: index)
                            }
                            if index > 0 && index < $0.points.count-1{
                                $0.segments[index-1] = Segment(id: UUID().uuidString, start: $0.points[index-1].coordinate, end: $0.points[index+1].coordinate)
                            }else if index == $0.points.count-1 {
                                $0.segments.remove(at: index-1)
                            }
                            $0.points.remove(at: index)
                        }
                    }
                    state.destination = nil
                    return .none
                case .point(.doneTapped):
                    if case let .point(pointState) = state.destination{
                        state.manager.apply {
                            $0.points.upsert(pointState.item)
                        }
                    }
                    state.destination = nil
                    return .none
                case .segment(.doneTapped):
                    if case let .segment(segmentState) = state.destination{
                        state.manager.apply {
                            guard let index = $0.segments.firstIndex(where: { $0.id == segmentState.item.id }) else { return }
                            $0.segments[index] = segmentState.item
                        }
                    }
                    state.destination = nil
                    return .none
                case .point(.cancelTapped),
                    .segment(.cancelTapped):
                    state.destination = nil
                    return .none
                case .point,
                    .segment:
                    return .none
                }
            case .destination(.dismiss):
                state.destination = nil
                return .none
            case .alert(.presented(.okTapped)):
                state.alert = nil
                return .none
            case .alert:
                return .none
            }
        }
        .ifLet(\.$destination, action: \.destination)
        .ifLet(\.$alert, action: \.alert)
    }
}

extension AdminRouteMap.Destination.State: Equatable {}
extension AdminRouteMap.Destination.Action: Equatable {}
