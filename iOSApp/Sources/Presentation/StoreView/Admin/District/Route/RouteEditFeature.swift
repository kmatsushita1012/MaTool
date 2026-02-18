//
//  RouteEditFeature.swift
//  MaTool
//
//  Created by 松下和也 on 2025/08/01.
//

import ComposableArchitecture
import Foundation
import MapKit
import Shared
import SQLiteData

@Reducer
struct RouteEditFeature{
    
    enum Destination: Equatable {
        case preview(ExportedItem)
        case history
        case passage
    }
    
    enum EditMode: Equatable {
        case create
        case update
        case preview
    }
    
    enum Tab: Equatable {
        case info
        case edit
        case `public`
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
        var manager: EditManager<[Point]>
        var route: Route
        var passages: [RoutePassage]
        
        @FetchOne var district: District
        @FetchOne var period: Period
        
        let mode: EditMode
        var operation: Operation = .add
        var isLoading: Bool = false
        var tab: Tab
        var region: MKCoordinateRegion
        var size: CGSize?
        
        // Navigation
        @Presents var point: PointEditFeature.State?
        @Presents var alert: AlertDestination.State? = nil
        var destination: Destination?
    }
    
    @CasePathable
    enum Action: Equatable, BindableAction{
        case binding(BindingAction<State>)
        case mapLongPressed(Coordinate)
        case pointTapped(PointEntry)
        case undoTapped
        case redoTapped
        case saveTapped
        case cancelTapped
        case deleteTapped
        case wholeTapped
        case partialTapped
        case copyTapped
        case passageAddTapped
        case passageSelected(District)
        case passageMoved(from: IndexSet, to: Int)
        case passageDeleteTapped(IndexSet)
        case sourceSelected(RouteEntry)
        case saveReceived(VoidTaskResult)
        case copyPrepared(TaskResult<Route.ID>)
        case deleteReceived(VoidTaskResult)
        case previewPrepared(TaskResult<ExportedItem>)
        case point(PresentationAction<PointEditFeature.Action>)
        case alert(PresentationAction<AlertDestination.Action>)
    }
    
    @Dependency(RouteDataFetcherKey.self) var dataFetcher
    @Dependency(\.dismiss) var dismiss
    
    var body: some ReducerOf<RouteEditFeature> {
        BindingReducer()
        Reduce{ state, action in
            switch action {
            case .mapLongPressed(let coordinate):
                switch state.operation {
                case .add:
                    let point = Point(id: UUID().uuidString, routeId: state.route.id, coordinate: coordinate)
                    state.points.append(point)
                    return .none
                case .move(let index):
                    if index < 0 || index >= state.points.count { return .none }
                    state.points[index].coordinate = coordinate
                    state.operation = .add
                    return .none
                case .insert(let index):
                    if index < 0 || index >= state.points.count { return .none }
                    let point = Point(id: UUID().uuidString, routeId: state.route.id, coordinate: coordinate)
                    state.points.insert(point, at: index)
                    state.operation = .add
                    return .none
                }
            case .pointTapped(let entry):
                state.point = PointEditFeature.State(entry.point)
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
                state.isLoading = true
                return .task(Action.saveReceived) {[state] in
                    try state.points.validate()
                    switch state.mode {
                    case .create:
                        try await dataFetcher.create(districtID: state.route.districtId, route: state.route, points: state.points, passages: state.passages)
                    case .update:
                        try await dataFetcher.update(state.route, points: state.points, passages: state.passages)
                    case .preview:
                        throw APIError.unknown(message: "権限がありません")
                    }
                    await dismiss()
                }
            case .cancelTapped:
                return .dismiss
            case .deleteTapped:
                if !state.isDeleteable {
                    state.alert = .notice(Alert.error("権限がありません"))
                    return .none
                }
                state.alert = .delete(Alert.delete())
                return .none
            case .wholeTapped:
                return .task(Action.previewPrepared){ [state] in
                    let snapshotter = try await RouteSnapshotter(route: state.route, points: state.points)
                    let (image, url) = try await snapshotter.take()
                    return ExportedItem(image: image, url: url)
                }
            case .partialTapped:
                guard  let size = state.size else {
                    state.alert = .notice(.error("描画範囲の取得に失敗しました。"))
                      return .none
                }
                return .task(Action.previewPrepared){ [state] in
                    let snapshotter = try await RouteSnapshotter(route: state.route, points: state.points)
                    let (image, url) = try await snapshotter.take(of: state.region, size: size)
                    return ExportedItem(image: image, url: url)
                }
            case .copyTapped:
                state.destination = .history
                return .none
            case .passageAddTapped:
                state.destination = .passage
                return .none
            case .passageSelected(let district):
                state.passages.append(.init(routeId: state.route.id, districtId: district.id))
                state.destination = nil
                return .none
            case .passageDeleteTapped(let index):
                state.passages.remove(atOffsets: index)
                return .none
            case let .passageMoved(from: source, to: destination):
                state.passages.move(fromOffsets: source, toOffset: destination)
                return .none
            case .sourceSelected(let route):
                state.isLoading = true
                state.destination = nil
                return .task(Action.copyPrepared) {
                    try await dataFetcher.fetch(routeID: route.id)
                    return route.id
                }
            // MARK: - Received
            case .copyPrepared(.success(let routeId)):
                state.isLoading = false
                guard let sourceRoute: Route = FetchOne(Route.find(routeId)).wrappedValue else { return .none }
                let sourcePoints: [Point] = FetchAll(routeId: sourceRoute.id).wrappedValue
                let sourcePassages: [RoutePassage] = FetchAll(routeId: sourceRoute.id).wrappedValue
                state.route = sourceRoute.copyWith(districtId: state.district.id, periodId: state.period.id)
                state.points = sourcePoints.copyWith(routeId: state.route.id)
                state.passages = sourcePassages.copyWith(routeId: state.route.id)
                state.region = makeRegion(state.points.map(\.coordinate))
                state.isLoading = false
                return .none
            case .previewPrepared(.success(let item)):
                state.destination = .preview(item)
                state.isLoading = false
                return .none
            // MARK: - Destination
            case .point(.presented(.moveTapped)):
                if let (point, index) = findPointIndex(state){
                    state.points[index] = point
                    state.operation = .move(index)
                    state.point = nil
                }
                return .none
            case .point(.presented(.insertTapped)):
                if let (point, index) = findPointIndex(state){
                    state.points[index] = point
                    state.operation = .insert(index)
                    state.point = nil
                }
                return .none
            case .point(.presented(.deleteTapped)):
                if let (point, index) = findPointIndex(state, ignoreValidation: true){
                    state.points[index] = point
                    state.points.remove(at: index)
                    state.point = nil
                }
                return .none
            case .point(.presented(.doneTapped)):
                if let (point, _) = findPointIndex(state) {
                    state.points.upsert(point)
                    state.point = nil
                }
                return .none
            case .alert(.presented(let destination)):
                switch destination {
                case .notice(.okTapped):
                    state.alert = nil
                    return .none
                case .delete(.okTapped):
                    state.alert = nil
                    state.isLoading = true
                    return .task(Action.deleteReceived) { [state] in
                        try await dataFetcher.delete(state.route.id)
                        await dismiss()
                    }
                }
            // MARK: - Error
            case .saveReceived(.failure(let error)),
                .deleteReceived(.failure(let error)),
                .copyPrepared(.failure(let error)),
                .previewPrepared(.failure(let error)):
                state.isLoading = false
                state.alert = .notice(.error(error.localizedDescription))
                return .none
            default:
                return .none
            }
        }
        .ifLet(\.$point, action: \.point){
            PointEditFeature()
        }
        .ifLet(\.$alert, action: \.alert)
    }
}

extension RouteEditFeature.AlertDestination.State: Equatable {}
extension RouteEditFeature.AlertDestination.Action: Equatable {}

extension RouteEditFeature.State {
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
    
    var points: [Point] {
        get {
            manager.value
        }
        set {
            manager.apply { $0 = newValue }
        }
    }
    
    var pointEntries: [PointEntry] {
        points.map{ PointEntry($0) }
    }
    
    init(mode: RouteEditFeature.EditMode, route: Route, district: District, period: Period){
        self.mode = mode
        let points: [Point] = FetchAll(routeId: route.id).wrappedValue
        self.manager = EditManager(points.sorted())
        self.passages = FetchAll(routeId: route.id).wrappedValue
        self.route = route
        self._district = FetchOne(wrappedValue: district, District.find(district.id))
        self._period = FetchOne(wrappedValue: period, Period.find(period.id))
        
        let origin: Coordinate = district.base ?? FetchOne(wrappedValue: .init(latitude: 0.0, longitude: 0.0), Festival.where{ $0.id == district.festivalId }.select(\.base)).wrappedValue

        self.region = makeRegion(points: points, origin: origin, spanDelta: spanDelta)
        if mode == .preview {
            self.tab = .edit
        }else{
            self.tab = .info
        }
    }
}

extension RouteEditFeature {
    func findPointIndex(
        _ state: State,
        ignoreValidation: Bool = false
    ) -> (point: Point, index: Int)? {

        guard let wrapper = state.point else {
            return nil
        }

        if !ignoreValidation {
            do {
                try wrapper.validate()
            } catch {
                return nil
            }
        }

        let point = wrapper.point

        guard let index = state.points.firstIndex(where: { $0.id == point.id }) else {
            return nil
        }

        return (point, index)
    }
}

extension RouteEditFeature.Destination: Identifiable {
    var id: String {
        switch self {
        case .preview(let exportedItem):
            return "preview-\(exportedItem.id)"
        case .history:
            return "history"
        case .passage:
            return "passage"
        }
    }
}
