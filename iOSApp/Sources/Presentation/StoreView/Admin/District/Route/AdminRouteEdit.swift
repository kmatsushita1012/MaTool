//
//  AdminRouteEdit.swift
//  MaTool
//
//  Created by 松下和也 on 2025/08/01.
//

import ComposableArchitecture
import Foundation
import MapKit
import Shared

@Reducer
struct AdminRouteEdit{
    
    enum Destination: Equatable {
        case point
        case whole
        case partial
    }
    
    enum EditMode: Equatable {
        case create
        case update
        case preview
    }
    
    enum Tab: Equatable {
        case info
        case map
        case pub
    }
    
    enum Operation: Equatable{
        case add
        case move(Int)
        case insert(Int)
    }
    
    @Reducer
    enum AlertDestination{
        case notice(Alert)
        case delete(Alert)
    }
    
    @ObservableState
    struct State: Equatable{
        let mode: EditMode
        let districtName: String
        let milestones: [Information]
        var manager: EditManager<Route>
        
        var operation: Operation = .add
        var isLoading: Bool = false
        var tab: Tab
        
        var region: MKCoordinateRegion?
        var size: CGSize?
        
        @Presents var point: AdminPointEdit.State?
        @Presents var alert: AlertDestination.State? = nil
        var whole: ExportedItem? = nil
        var partial: ExportedItem? = nil
        
        var canUndo: Bool { manager.canUndo }
        var canRedo: Bool{ manager.canRedo }
        var isSaveable: Bool { mode != .preview }
        var isDeleteable: Bool { mode == .update}
        var isPartialEnable: Bool { tab != .info }
        var title: String {
            switch mode {
            case .create:
                return "新規作成"
            case .update:
                return "編集"
            case .preview:
                return "修正"
            }
        }
        
        var route: Route {
            get {
                manager.value
            }
            set {
                manager.apply { $0 = newValue }
            }
        }
        
        var filter: PointFilter{
            switch tab {
            case .info, .map:
                return .none
            case .pub:
                return .pub
            }
        }
        
        init(mode: EditMode, route: Route, districtName: String, milestones: [Information], origin: Coordinate){
            self.mode = mode
            self.manager = EditManager(route)
            self.districtName = districtName
            self.milestones = milestones
            if !route.points.isEmpty{
                self.region = makeRegion(route.points.map{ $0.coordinate })
            }else{
                self.region = makeRegion(origin: origin, spanDelta: spanDelta)
            }
            if mode == .preview {
                self.tab = .map
            }else{
                self.tab = .info
            }
            
        }
    }
    
    @CasePathable
    enum Action: Equatable, BindableAction{
        case binding(BindingAction<State>)
        case mapLongPressed(Coordinate)
        case pointTapped(Point)
        case undoTapped
        case redoTapped
        case saveTapped
        case cancelTapped
        case deleteTapped
        case wholeTapped
        case partialTapped
        case postReceived(Result<Route, APIError>)
        case deleteReceived(Result<Route, APIError>)
        case wholePrepared(ExportedItem?)
        case partialPrepared(ExportedItem?)
        case point(PresentationAction<AdminPointEdit.Action>)
        case alert(PresentationAction<AlertDestination.Action>)
    }
    
    @Dependency(\.apiRepository) var apiRepository
    @Dependency(\.dismiss) var dismiss
    
    var body: some ReducerOf<AdminRouteEdit> {
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
                    }
                    return .none
                case .move(let index):
                    if index < 0 || index >= state.route.points.count { return .none }
                    state.manager.apply{
                        $0.points[index].coordinate = coordinate
                    }
                    state.operation = .add
                    return .none
                case .insert(let index):
                    if index < 0 || index >= state.route.points.count { return .none }
                    let point = Point(id: UUID().uuidString, coordinate: coordinate)
                    state.manager.apply{
                        $0.points.insert(point, at: index)
                    }
                    state.operation = .add
                    return .none
                }
            case .pointTapped(let point):
                state.point = AdminPointEdit.State(item: point, milestones: state.milestones)
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
            case .saveTapped:
                if !state.isSaveable {
                    state.alert = .notice(Alert.error("権限がありません"))
                    return .none
                } else if state.route.title.isEmpty {
                    state.alert = .notice(Alert.error("タイトルは1文字以上を指定してください。"))
                    return .none
                } else if state.route.title.contains("/") {
                    state.alert = .notice(Alert.error("タイトルに\"/\"を含むことはできません"))
                    return .none
                } else if state.route.start >= state.route.goal{
                    state.alert = .notice(Alert.error("終了時刻は開始時刻より前に設定してください"))
                    return .none
                }
                state.isLoading = true
                return .run { [
                    route = state.route,
                    mode = state.mode
                ] send in
                    switch mode {
                    case .create:
                        let result = await apiRepository.postRoute(route)
                        await send(.postReceived(result))
                    case .update:
                        let result = await apiRepository.putRoute(route)
                        await send(.postReceived(result))
                    case .preview:
                        break
                    }
                }
            case .cancelTapped:
                return .run { _ in
                    await dismiss()
                }
            case .deleteTapped:
                if !state.isSaveable {
                    state.alert = .notice(Alert.error("権限がありません"))
                    return .none
                }
                state.alert = .delete(Alert.delete())
                return .none
            case .wholeTapped:
                return .run {[
                    route = state.route,
                    districtName = state.districtName
                ] send in
                    let snapshotter = RouteSnapshotter(route, districtName: districtName)
                    if let image = try? await snapshotter.take(),
                       let pdf = snapshotter.createPDF(
                        with: image,
                        path: "\(districtName)_\(route.text(format: "y-m-d_T")).pdf"
                       ) {
                        await send(.wholePrepared(ExportedItem(image: image, pdf: pdf)))
                    }else {
                        await send(.wholePrepared(nil))
                    }
                }
            case .partialTapped:
                guard let region = state.region,
                  let size = state.size else {
                      return .none
                }
                return .run { [
                    districtName = state.districtName,
                    route = state.route
                ] send in
                    let snapshotter = RouteSnapshotter(route, districtName: districtName)
                    if let image = try? await snapshotter.take(of: region, size: size),
                       let pdf = snapshotter.createPDF(with: image, path: "\(districtName)_\(route.text(format: "y-m-d_T"))_part_\(Date().stamp).pdf") {
                        await send(.partialPrepared(ExportedItem(image: image, pdf: pdf)))
                    } else {
                        await send(.partialPrepared(nil))
                    }
                }
            case .postReceived(let result):
                state.isLoading = false
                if case let .failure(error) = result {
                    state.alert = .notice(Alert.error("情報の取得に失敗しました。 \(error.localizedDescription)"))
                }
                return .none
            case .deleteReceived(let result):
                state.isLoading = false
                if case let .failure(error) = result {
                    state.alert = .notice(Alert.error("情報の取得に失敗しました。 \(error.localizedDescription)"))
                }
                return .none
            case .wholePrepared(let item):
                state.whole = item
                return .none
            case .partialPrepared(let item):
                state.partial = item
                return .none
            case .point(.presented(let childAction)):
                switch childAction {
                case .moveTapped:
                    if let pointState = state.point,
                       let index = state.route.points.firstIndex(where: { $0.id == pointState.item.id }){
                        state.manager.apply {
                            $0.points[index] = pointState.item
                        }
                        state.operation = .move(index)
                    }
                    state.point = nil
                    return .none
                case .insertTapped:
                    if let pointState = state.point,
                       let index = state.route.points.firstIndex(where: { $0.id == pointState.item.id }){
                        state.manager.apply {
                            $0.points[index] = pointState.item
                        }
                        state.operation = .insert(index)
                    }
                    state.point = nil
                    return .none
                case .deleteTapped:
                    if let pointState = state.point,
                       let index = state.route.points.firstIndex(where: { $0.id == pointState.item.id }){
                        state.manager.apply {
                            $0.points.remove(at: index)
                        }
                    }
                    state.point = nil
                    return .none
                case .doneTapped:
                    if let pointState = state.point{
                        state.manager.apply {
                            $0.points.upsert(pointState.item)
                        }
                    }
                    state.point = nil
                    return .none
                default:
                    return .none
                }
            case .point(.dismiss):
                return .none
            case .alert(.presented(let destination)):
                switch destination {
                case .notice(.okTapped):
                    state.alert = nil
                    return .none
                case .delete(.okTapped):
                    state.alert = nil
                    state.isLoading = true
                    return .run { [route = state.route] send in
                        let result = await apiRepository.deleteRoute(route.id)
                        await send(.postReceived(result))
                    }
                }
            case .alert(.dismiss):
                return .none
            }
        }
        .ifLet(\.$point, action: \.point){
            AdminPointEdit()
        }
        .ifLet(\.$alert, action: \.alert)
    }
}

extension AdminRouteEdit.AlertDestination.State: Equatable {}
extension AdminRouteEdit.AlertDestination.Action: Equatable {}

struct ExportedItem: Identifiable, Equatable {
    let id = UUID()
    let image: UIImage
    let pdf: URL
}
