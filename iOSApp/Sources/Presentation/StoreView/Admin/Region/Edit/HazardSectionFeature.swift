//
//  HazardSectionFeature.swift
//  MaTool
//
//  Created by 松下和也 on 2025/12/09.
//

import ComposableArchitecture
import Shared
import MapKit

@Reducer
struct HazardSectionFeature {
    
    enum Mode: Equatable {
        case add
        case insertBefore(Int)
        case insertAfter(Int)
    }
    
    @ObservableState
    struct State: Equatable {
        var mode: Mode = .add
        var manager: EditManager<HazardSection>
        var selectedPin: Coordinate?
        var mapRegion: MKCoordinateRegion?
        @Presents var alert: AlertFeature.State?
        
        init(_ item: HazardSection, mapRegion: MKCoordinateRegion) {
            self.manager = .init(item)
            self.mapRegion = mapRegion
        }
    }
    
    @CasePathable
    enum Action: Equatable, BindableAction {
        case binding(BindingAction<State>)
        case mapLongPressed(Coordinate)
        case pinSelected(Coordinate)
        case doneTapped
        case deleteTapped
        case redoTapped
        case undoTapped
        case clearTapped
        case insertBeforeTapped(Coordinate)
        case insertAfterTapped(Coordinate)
        case removeTapped(Coordinate)
        case menuClosed
        case alert(PresentationAction<AlertFeature.Action>)
    }
    
    var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .mapLongPressed(let coordinate):
                switch state.mode {
                case .add:
                    state.manager.apply {
                        $0.coordinates.append(coordinate)
                    }
                case .insertBefore(let index):
                    state.manager.apply {
                        $0.coordinates.insert(coordinate, before: index)
                    }
                    state.mode = .add
                case .insertAfter(let index):
                    state.manager.apply {
                        $0.coordinates.insert(coordinate, after: index)
                    }
                    state.mode = .add
                }
                return .none
            case .pinSelected(let coordinate):
                state.selectedPin = coordinate
                return .none
            case .doneTapped:
                if !state.isValid {
                    state.alert = AlertFeature.error("タイトルを1文字以上、地点を2つ以上入力してください。")
                }
                return .none
            case .redoTapped:
                state.manager.redo()
                state.mode = .add
                return .none
            case .undoTapped:
                state.manager.undo()
                state.mode = .add
                return .none
            case .clearTapped:
                state.item.coordinates = []
                state.mode = .add
                return .none
            case .insertBeforeTapped(let coordinate):
                guard let index = state.item.coordinates.firstIndex(of: coordinate) else { return .none }
                state.mode = .insertBefore(index)
                return .none
            case .insertAfterTapped(let coordinate):
                guard let index = state.item.coordinates.firstIndex(of: coordinate) else { return .none }
                state.mode = .insertAfter(index)
                return .none
            case .removeTapped(let coordinate):
                state.manager.apply{
                    $0.coordinates.removeAll(of: coordinate)
                }
                state.mode = .add
                return .none
            case .menuClosed:
                state.selectedPin = nil
                return .none
            case .alert:
                state.alert = nil
                return .none
            default:
                /// deleteTapped
                return .none
            }
        }
    }
}

extension HazardSectionFeature.State {
    init(mapRegion: MKCoordinateRegion, festivalId: Festival.ID) {
        let item = HazardSection(id: UUID().uuidString
                                 , title: "", festivalId: festivalId, coordinates: [])
        self.manager = .init(item)
        self.mapRegion = mapRegion
    }
    
    var item: HazardSection {
        get {
            manager.value
        }
        set {
            manager.apply { $0 = newValue }
        }
    }
    
    var isValid: Bool {
        item.coordinates.count > 1 && !item.title.isEmpty
    }
}
