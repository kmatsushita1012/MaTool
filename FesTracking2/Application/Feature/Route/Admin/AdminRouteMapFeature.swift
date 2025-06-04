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
        var manager: EditManager<Route>
        var canUndo: Bool { manager.canUndo }
        var canRedo: Bool{ manager.canRedo }
        let performances: [Performance]
        var region: MKCoordinateRegion?
        var route: Route {
            manager.value
        }
        @Presents var pointAdmin: AdminPointFeature.State?
        @Presents var segmentAdmin: AdminSegmentFeature.State?
        @Presents var alert: OkAlert.State?
        
        init(route: Route, performances: [Performance], base: Coordinate?){
            self.manager = EditManager(route)
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
            case .mapLongPressed(let coordinate):
                let next = Point(id: UUID().uuidString, coordinate: coordinate, title: nil, description: nil, time: nil, isPassed: false)
                state.manager.apply{
                    if let last = $0.points.last{
                        let segment = Segment(id: UUID().uuidString, start: last.coordinate, end: next.coordinate)
                        $0.segments.append(segment)
                    }
                    $0.points.append(next)
                }
                return .none
            case .annotationTapped(let point):
                state.pointAdmin = AdminPointFeature.State(item: point, performances: state.performances)
                return .none
            case .polylineTapped(let segment):
                state.segmentAdmin = AdminSegmentFeature.State(item: segment)
                return .none
            case .undoTapped:
                state.manager.undo()
                return .none
            case .redoTapped:
                state.manager.redo()
                return .none
            case .doneTapped:
                return .none
            case .cancelTapped:
                return .none
            case .pointAdmin(.presented(.doneTapped)):
                if let pointAdmin = state.pointAdmin{
                    state.manager.apply {
                        if let index = $0.points.firstIndex(where: { $0.id == pointAdmin.item.id }) {
                            $0.points[index] = pointAdmin.item
                        }
                    }
                }
                state.pointAdmin = nil
                return .none
            case .pointAdmin(.presented(.cancelTapped)),
                .pointAdmin(.dismiss):
                state.pointAdmin = nil
                return .none
            case .pointAdmin:
                return .none
            case .segmentAdmin(.presented(.saveTapped)):
                if let segmentAdmin = state.segmentAdmin{
                    state.manager.apply {
                        if let index = $0.segments.firstIndex(where: { $0.id == segmentAdmin.item.id }) {
                            $0.segments[index] = segmentAdmin.item
                        }
                    }
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
