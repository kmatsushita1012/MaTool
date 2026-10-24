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

@Reducer
struct RouteEditFeature{
    
    enum Destination: Equatable {
        case preview(ExportedItem)
        case history([RouteEntry])
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
        case notice(AlertFeature)
        case delete(AlertFeature)
    }
    
    @ObservableState
    struct State: Equatable{
        var manager: EditManager<[Point]>
        var route: Route
        var passages: [RoutePassage]
        
        var district: District
        var festival: Festival
        var period: Period
        @Shared fileprivate var appState: AppState?
        
        var mode: EditMode
        var operation: Operation = .add
        var isLoading: Bool = false
        var isSubmitDialogPresented: Bool = false
        var tab: Tab
        var districtAreaOverlays: [DistrictAreaOverlay]
        var isDistrictAreaOverlayVisible: Bool = false
        var passageInsertIndex: Int? = nil
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
        case onAppear
        case mapLongPressed(Coordinate)
        case pointTapped(PointEntry)
        case districtAreaOverlayTapped
        case autoPassageTapped
        case undoTapped
        case redoTapped
        case saveTapped
        case modified(VoidAppResult)
        case cancelTapped
        case deleteTapped
        case wholeTapped
        case partialTapped
        case copyTapped
        case passageAddTapped
        case passageInsertAboveTapped(Int)
        case passageInsertBelowTapped(Int)
        case passageSelected(districtId: District.ID?, memo: String?)
        case passageMoved(from: IndexSet, to: Int)
        case passageDeleteTapped(Int)
        case sourceSelected(RouteEntry)
        case historyPrepared(AppResult<[RouteEntry]>)
        case saveReceived(VoidAppResult)
        case copyPrepared(AppResult<RoutePack>)
        case deleteReceived(VoidAppResult)
        case previewPrepared(AppResult<ExportedItem>)
        case point(PresentationAction<PointEditFeature.Action>)
        case alert(PresentationAction<AlertDestination.Action>)
    }
    
    @Dependency(CreateRouteUseCaseKey.self) var createRouteUseCase
    @Dependency(UpdateRouteUseCaseKey.self) var updateRouteUseCase
    @Dependency(DeleteRouteUseCaseKey.self) var deleteRouteUseCase
    @Dependency(FetchRoutePackUseCaseKey.self) var fetchRoutePackUseCase
    @Dependency(FetchRouteHistoryUseCaseKey.self) var fetchRouteHistoryUseCase
    @Dependency(\.dismiss) var dismiss
    
    var body: some ReducerOf<RouteEditFeature> {
        BindingReducer()
        Reduce{ state, action in
            switch action {
            case .onAppear:
                if !state.district.isEditable && state.mode != .preview {
                    state.alert = .notice(.notice("\(state.festival.subname)がルートの更新を停止しています。"))
                }
                return .none
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
                state.point = PointEditFeature.State(
                    entry.point,
                    districtId: state.district.id,
                    appState: state.$appState
                )
                state.operation = .add
                return .none
            case .districtAreaOverlayTapped:
                guard state.canShowDistrictAreaOverlay else { return .none }
                state.isDistrictAreaOverlayVisible.toggle()
                return .none
            case .autoPassageTapped:
                let districts = state.appState?.festivalState.districts ?? []
                let detector = RoutePassageAutoDetector(mode: .includeTouch)
                state.passages = detector.makePassages(routeId: state.route.id, points: state.points, districts: districts)
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
                let points = state.points.normalized().reindexed()
                do {
                    try points.validate()
                } catch {
                    state.alert = .notice(.error(error.localizedDescription))
                    return .none
                }
                switch state.mode {
                case .preview:
                    return .task(Action.modified) {
                        await dismiss()
                    }
                case .create, .update:
                    state.isLoading = true
                    return .task(Action.saveReceived) {[state, points, appState = state.$appState] in
                        switch state.mode {
                        case .create:
                            _ = try await createRouteUseCase(
                                districtId: state.route.districtId,
                                route: state.route,
                                points: points,
                                passages: state.passages,
                                appState: appState
                            )
                        case .update:
                            _ = try await updateRouteUseCase(
                                state.route,
                                points: points,
                                passages: state.passages,
                                appState: appState
                            )
                        case .preview:
                            throw AppError.be(.forbidden("権限がありません"))
                        }
                        await dismiss()
                    }
                }
            case .modified(.success):
                return .none
            case .modified(.failure(let error)):
                state.alert = .notice(.error(error.localizedDescription))
                return .none
            case .cancelTapped:
                return .dismiss
            case .deleteTapped:
                if !state.isDeleteable {
                    state.alert = .notice(AlertFeature.error("権限がありません"))
                    return .none
                }
                state.alert = .delete(AlertFeature.delete())
                return .none
            case .wholeTapped:
                state.isLoading = true
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
                state.isLoading = true
                return .task(Action.previewPrepared){ [state] in
                    let snapshotter = try await RouteSnapshotter(route: state.route, points: state.points)
                    let (image, url) = try await snapshotter.take(of: state.region, size: size)
                    return ExportedItem(image: image, url: url)
                }
            case .copyTapped:
                state.isLoading = true
                let districtId = state.district.id
                let festivalId = state.festival.id
                return .task(Action.historyPrepared) {
                    try await fetchRouteHistoryUseCase(districtId: districtId, festivalId: festivalId)
                }
            case .passageAddTapped:
                state.passageInsertIndex = nil
                state.destination = .passage
                return .none
            case .passageInsertAboveTapped(let index):
                state.passageInsertIndex = index
                state.destination = .passage
                return .none
            case .passageInsertBelowTapped(let index):
                state.passageInsertIndex = min(index + 1, state.passages.count)
                state.destination = .passage
                return .none
            case .passageSelected(let districtId, let memo):
                let newPassage = RoutePassage(routeId: state.route.id, districtId: districtId, memo: memo)
                if let insertIndex = state.passageInsertIndex,
                   insertIndex >= 0,
                   insertIndex <= state.passages.count {
                    state.passages.insert(newPassage, at: insertIndex)
                } else {
                    state.passages.append(newPassage)
                }
                state.passageInsertIndex = nil
                state.destination = nil
                return .none
            case .passageDeleteTapped(let index):
                state.passages.remove(at: index)
                return .none
            case let .passageMoved(from: source, to: destination):
                state.passages.move(fromOffsets: source, toOffset: destination)
                return .none
            case .sourceSelected(let route):
                state.isLoading = true
                state.destination = nil
                return .task(Action.copyPrepared) {
                    try await fetchRoutePackUseCase(routeId: route.id)
                }
            // MARK: - Received
            case .historyPrepared(.success(let entries)):
                state.isLoading = false
                state.destination = .history(entries)
                return .none
            case .copyPrepared(.success(let pack)):
                state.isLoading = false
                state.route = pack.route.copyWith(districtId: state.district.id, periodId: state.period.id)
                state.mode = .create
                state.points = pack.points.sorted().copyWith(routeId: state.route.id).normalized().reindexed()
                state.passages = pack.passages
                    .sorted { $0.order < $1.order }
                    .copyWith(routeId: state.route.id)
                    .reindexed()
                let origin = state.district.base ?? state.festival.base
                state.region = makeRegion(points: state.points, origin: origin, spanDelta: spanDelta)
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
            case .point(.presented(.insertBeforeTapped)):
                if let (point, index) = findPointIndex(state){
                    state.points[index] = point
                    state.operation = .insert(index)
                    state.point = nil
                }
                return .none
            case .point(.presented(.insertAfterTapped)):
                if let (point, index) = findPointIndex(state){
                    state.points[index] = point
                    let targetIndex = index + 1
                    if targetIndex < state.points.count {
                        state.operation = .insert(targetIndex)
                    }
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
                    return .task(Action.deleteReceived) { [routeId = state.route.id, appState = state.$appState] in
                        try await deleteRouteUseCase(routeId: routeId, appState: appState)
                        await dismiss()
                    }
                default:
                    state.alert = nil
                    return .none
                }
            // MARK: - Error
            case .saveReceived(.failure(let error)),
                .deleteReceived(.failure(let error)),
                .historyPrepared(.failure(let error)),
                .copyPrepared(.failure(let error)),
                .previewPrepared(.failure(let error)):
                state.isLoading = false
                state.alert = .notice(.error(error))
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
    var isConfirmDisabled: Bool { false }
    var isDeleteable: Bool { mode == .update}
    var isPartialEnable: Bool { tab != .info }
    var isAutoPassageDisabled: Bool { points.count < 2 }
    var canShowDistrictAreaOverlay: Bool { mode == .preview && !districtAreaOverlays.isEmpty }
    var saveButtonTitle: String {
        switch mode {
        case .preview:
            return "修正"
        case .create, .update:
            return "保存"
        }
    }
    var title: String {
        switch mode {
        case .create:
            return "新規作成"
        case .update:
            return "編集"
        case .preview:
            return "確認と修正"
        }
    }
    
    var points: [Point] {
        get {
            manager.value
        }
        set {
            manager.apply { $0 = newValue.normalized().reindexed() }
        }
    }
    
    var pointEntries: [PointEntry] {
        appState?.pointEntries(for: points, districtId: district.id) ?? []
    }

    var districts: [District] {
        appState?.festivalState.districts ?? []
    }

    var districtsById: [District.ID: District] {
        appState?.districtsById ?? [:]
    }
    
    var start: Point? {
        points.first
    }
    
    var end: Point? {
        points.last
    }
    
    init(
        mode: RouteEditFeature.EditMode,
        route: Route,
        appState: Shared<AppState?> = Shared(value: nil)
    ) throws {
        let routeState = appState.wrappedValue?.routeState(for: route.id)
        guard mode == .create || routeState != nil else {
            throw PresentationError.notFound
        }
        let points = routeState?.points ?? []
        let passages = routeState?.passages ?? []
        try self.init(
            mode: mode,
            draft: RouteDraft(route: route, points: points, passages: passages),
            appState: appState
        )
    }

    init(
        mode: RouteEditFeature.EditMode,
        draft: RouteDraft,
        appState: Shared<AppState?> = Shared(value: nil)
    ) throws {
        guard let current = appState.wrappedValue,
              let district = current.district(id: draft.route.districtId),
              let period = current.period(id: draft.route.periodId) else {
            throw PresentationError.notFound
        }
        self._appState = appState
        self.mode = mode
        self.manager = EditManager(draft.points.sorted().normalized().reindexed())
        self.passages = draft.passages
        self.route = draft.route
        self.district = district
        self.festival = current.festivalState.festival
        self.period = period
        self.districtAreaOverlays = assignDistrictAreaOverlays(districts: current.festivalState.districts)
        let origin = district.base ?? current.festivalState.festival.base
        self.region = makeRegion(points: draft.points, origin: origin, spanDelta: spanDelta)
        self.tab = .info
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
