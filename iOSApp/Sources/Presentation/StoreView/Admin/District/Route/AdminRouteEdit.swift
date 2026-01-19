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
import SQLiteData

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
        
        @FetchOne var district: District
        @FetchOne var period: Period
        
        let mode: EditMode
        var operation: Operation = .add
        var isLoading: Bool = false
        var tab: Tab
        var region: MKCoordinateRegion
        var size: CGSize?
        
        // Navigation
        @Presents var point: AdminPointEdit.State?
        @Presents var alert: AlertDestination.State? = nil
        var history: Bool = false
        var whole: ExportedItem? = nil
        var partial: ExportedItem? = nil
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
        case sourceSelected(RouteEntry)
        case copyPrepared(Route.ID)
        case taskFinished
        case apiErrorCatched(APIError)
        case wholePrepared(ExportedItem?)
        case partialPrepared(ExportedItem?)
        case point(PresentationAction<AdminPointEdit.Action>)
        case alert(PresentationAction<AlertDestination.Action>)
    }
    
    @Dependency(RouteDataFetcherKey.self) var dataFetcher
    @Dependency(\.dismiss) var dismiss
    
    var body: some ReducerOf<AdminRouteEdit> {
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
                state.point = AdminPointEdit.State(entry.point)
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
                }
                state.isLoading = true
                return .run { [
                    state
                ] send in
                    let result = await task{
                        switch state.mode {
                        case .create:
                            try await dataFetcher.create(districtID: state.route.districtId, route: state.route, points: state.points)
                        case .update:
                            try await dataFetcher.update(state.route, points: state.points)
                        case .preview:
                            throw APIError.unknown(message: "権限がありません")
                        }
                    }
                    switch result {
                    case .success:
                        await dismiss
                    case .failure(let error):
                        await send(.apiErrorCatched(error))
                    }
                }
            case .cancelTapped:
                return .run { _ in
                    await dismiss()
                }
            case .deleteTapped:
                if !state.isDeleteable {
                    state.alert = .notice(Alert.error("権限がありません"))
                    return .none
                }
                state.alert = .delete(Alert.delete())
                return .run { [state] send in
                    let result = await task{ try await dataFetcher.delete(state.route.id) }
                }
            case .wholeTapped:
                guard let snapshotter = RouteSnapshotter(state.route) else {
                    state.alert = .notice(Alert.error("時間帯の取得に失敗しました。"))
                    return .none
                }
                let path = "\(state.district.name)_\(state.period.shortText).pdf"
                return .run { send in
                    if let image = try? await snapshotter.take(),
                       let pdf = snapshotter.createPDF(
                        with: image,
                        path: path
                       ) {
                        await send(.wholePrepared(ExportedItem(image: image, pdf: pdf)))
                    }else {
                        await send(.wholePrepared(nil))
                    }
                }
            case .partialTapped:
                guard  let size = state.size else {
                    state.alert = .notice(Alert.error("描画範囲の取得に失敗しました。"))
                      return .none
                }
                guard let snapshotter = RouteSnapshotter(state.route) else {
                    state.alert = .notice(Alert.error("時間帯の取得に失敗しました。"))
                    return .none
                }
                let path =  "\(state.district.name)_\(state.period.shortText).pdf"
                return .run { [region = state.region] send in
                    if let image = try? await snapshotter.take(of: region, size: size),
                       let pdf = snapshotter.createPDF(with: image, path: path) {
                        await send(.partialPrepared(ExportedItem(image: image, pdf: pdf)))
                    } else {
                        await send(.partialPrepared(nil))
                    }
                }
            case .copyTapped:
                state.history = true
                return .none
            case .sourceSelected(let route):
                state.isLoading = true
                state.history = false
                return .run { [state] send in
                    let result = await task{ try await dataFetcher.fetch(routeID: state.route.id) }
                    switch result {
                    case .success:
                        await send(.copyPrepared(route.id))
                    case .failure(let error):
                        await send(.apiErrorCatched(error))
                    }
                }
            case .copyPrepared(let routeId):
                guard let sourceRoute: Route = FetchOne(Route.find(routeId)).wrappedValue else { return .none }
                let sourcePoints: [Point] = FetchAll(routeId: sourceRoute.id).wrappedValue
                state.route = sourceRoute.copyWith(districtId: state.district.id, periodId: state.period.id)
                state.points = sourcePoints.copyWith(routeId: state.route.id)
                state.isLoading = false
                return .none
            case .apiErrorCatched(let error):
                state.isLoading = false
                state.alert = .notice(Alert.error("情報の取得に失敗しました。 \(error.localizedDescription)"))
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
                    if let point = state.point?.point,
                       let index = state.points.firstIndex(where: { $0.id == point.id }){
                        state.points[index] = point
                        state.operation = .move(index)
                    }
                    state.point = nil
                    return .none
                case .insertTapped:
                    if let point = state.point?.point,
                       let index = state.points.firstIndex(where: { $0.id == point.id }){
                        state.points[index] = point
                        state.operation = .insert(index)
                    }
                    state.point = nil
                    return .none
                case .deleteTapped:
                    if let point = state.point?.point,
                       let index = state.points.firstIndex(where: { $0.id == point.id }){
                        state.points.remove(at: index)
                    }
                    state.point = nil
                    return .none
                case .doneTapped:
                    if let point = state.point?.point{
                        state.points.upsert(point)
                    }
                    state.point = nil
                    return .none
                default:
                    return .none
                }
            case .alert(.presented(let destination)):
                switch destination {
                case .notice(.okTapped):
                    state.alert = nil
                    return .none
                case .delete(.okTapped):
                    state.alert = nil
                    state.isLoading = true
                    return .run { [route = state.route] send in
                        try? await dataFetcher.delete(route.id)
                    }
                }
            default:
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

extension AdminRouteEdit.State {
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
    
    init(mode: AdminRouteEdit.EditMode, route: Route, district: District, period: Period){
        self.mode = mode
        let points: [Point] = FetchAll(Point.where{ $0.routeId == route.id }).wrappedValue
        self.manager = EditManager(points)
        self.route = route
        self._district = FetchOne(wrappedValue: district)
        self._period = FetchOne(wrappedValue: period)
        
        if !points.isEmpty{
            self.region = makeRegion(points.map{ $0.coordinate })
        }else{
            let origin: Coordinate = district.base ?? FetchOne(wrappedValue: .init(latitude: 0.0, longitude: 0.0), Festival.where{ $0.id == district.festivalId }.select(\.base)).wrappedValue
            self.region = makeRegion(origin: origin, spanDelta: spanDelta)
        }
        if mode == .preview {
            self.tab = .edit
        }else{
            self.tab = .info
        }
    }
}
