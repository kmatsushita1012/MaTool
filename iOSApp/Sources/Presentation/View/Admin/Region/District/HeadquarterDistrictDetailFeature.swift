//
//  HeadquarterDistrictDetailFeature.swift
//  MaTool
//
//  Created by 松下和也 on 2026/01/24.
//

import ComposableArchitecture
import Shared
import Foundation

@Reducer
struct HeadquarterDistrictDetailFeature {
    enum ExportKind: Equatable {
        case submission
        case table
    }
    
    @Reducer
    enum Destination {
        case route(RouteEditFeature)
        case reissue(DistrictReissueFeature)
    }
    
    @ObservableState
    struct State: Equatable {
        @Shared fileprivate var appState: AppState?
        var routeDrafts: [Route.ID: RouteDraft] = [:]
        var district: District

        var routes: [RouteSlot] {
            appState?.routeSlots(for: district.id, routeOverrides: routeDrafts.mapValues(\.route)) ?? []
        }
        
        var isEditable: Bool = false
        var isLoading: Bool = false
        var activeExportKind: ExportKind? = nil
        
        @Presents var destination: Destination.State?
        @Presents var alert: AlertFeature.State?
        var url: URL? = nil

        init(_ district: District, appState: Shared<AppState?>) {
            self._appState = appState
            self.district = district
        }
    }
    
    @CasePathable
    enum Action: Equatable, BindableAction {
        case binding(BindingAction<State>)
        case editTapped
        case reissueTapped
        case routeSelected(RouteSlot)
        case resetDraftsTapped
        case batchExportTapped
        case tableExportTapped
        case updateReceived(AppResult<District>)
        case routeReceived(AppResult<RoutePack?>)
        case batchExportReceived(AppResult<URL>)
        case destination(PresentationAction<Destination.Action>)
        case alert(PresentationAction<AlertFeature.Action>)
    }
    
    @Dependency(SaveDistrictUseCaseKey.self) var saveDistrictUseCase
    @Dependency(FetchRoutePackUseCaseKey.self) var fetchRoutePackUseCase
    @Dependency(LoadRouteStateUseCaseKey.self) var loadRouteStateUseCase
    
    var body: some ReducerOf<HeadquarterDistrictDetailFeature> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .binding(_):
                return .none
            case .editTapped:
                if state.isEditable {
                    state.isLoading = true
                    return .task(Action.updateReceived) { [district = state.district, appState = state.$appState] in
                        try await saveDistrictUseCase(district: district, appState: appState)
                    }
                } else {
                    if let current = state.appState?.district(id: state.district.id) {
                        state.district = current
                    }
                    state.isEditable = true
                    return .none
                }
            case .reissueTapped:
                state.destination = .reissue(.init(districtId: state.district.id, appState: state.$appState))
                return .none
            case .routeSelected(let slot):
                guard let route = slot.route else { return .none }
                if let draft = state.routeDrafts[route.id] {
                    state.destination = try? { .route(try .init(mode: .preview, draft: draft, appState: state.$appState)) }()
                    return .none
                }
                state.isLoading = true
                return .task(Action.routeReceived) { [routeId = route.id, appState = state.$appState] in
                    try await loadRouteStateUseCase(routeId: routeId, appState: appState)
                }
            case .batchExportTapped:
                state.activeExportKind = .submission
                return exportEffect(state: state, path: state.district.pdfFileName(), includesRouteMap: true)
            case .tableExportTapped:
                state.activeExportKind = .table
                return exportEffect(state: state, path: state.district.pdfFileName(suffix: "_行動表"), includesRouteMap: false)
            case .resetDraftsTapped:
                guard !state.routeDrafts.isEmpty else { return .none }
                state.routeDrafts = [:]
                return .none
            case .updateReceived(.success(let district)):
                state.isLoading = false
                state.district = district
                state.isEditable = false
                return .none
            case .routeReceived(.success(let pack)):
                state.isLoading = false
                guard let pack else { return .none }
                let draft = RouteDraft(route: pack.route, points: pack.points, passages: pack.passages)
                do {
                    state.destination = .route(try .init(mode: .preview, draft: draft, appState: state.$appState))
                } catch {
                    state.alert = .error(error.localizedDescription)
                }
                return .none
            case .destination(.presented(.route(.modified(.success)))):
                guard let routeState = state.destination?.route else { return .none }
                let draft = RouteDraft(
                    route: routeState.route,
                    points: routeState.points,
                    passages: routeState.passages
                )
                state.routeDrafts[draft.route.id] = draft
                return .none
            case .batchExportReceived(.success(let url)):
                state.activeExportKind = nil
                state.url = url
                return .none
            case .updateReceived(.failure(let error)),
                .routeReceived(.failure(let error)),
                .batchExportReceived(.failure(let error)):
                state.isLoading = false
                state.activeExportKind = nil
                state.alert = AlertFeature.error(error.message)
                return .none
            case .destination(_):
                return .none
            case .alert(_):
                return .none
            }
        }
        .ifLet(\.$destination, action: \.destination)
        .ifLet(\.$alert, action: \.alert)
    }
    
    func exportEffect(state: State, path: String, includesRouteMap: Bool) -> Effect<Action> {
        .task(Action.batchExportReceived) {
            //非同期並列にするとBEでアクセス過多
            let renderer = await PDFRenderer(path: path)
            let routes = state.routes.compactMap(\.route)
            var routePacks: [RoutePack] = []
            for route in routes {
                if let draft = state.routeDrafts[route.id] {
                    routePacks.append(RoutePack(route: draft.route, points: draft.points, passages: draft.passages))
                    continue
                }
                guard let pack = try? await fetchRoutePackUseCase(routeId: route.id) else { continue }
                routePacks.append(pack)
            }
            let tableSnapshotter = await ActionTableSnapshotter(
                district: state.district,
                slots: state.routes,
                routePacks: routePacks
            )
            let tablePages = await tableSnapshotter.takeAll()
            for page in tablePages {
                await renderer.addPage(with: page)
            }
            guard includesRouteMap else {
                let url = await renderer.finalize()
                return url
            }
            for route in routes {
                guard let pack = routePacks.first(where: { $0.route.id == route.id }),
                      let snapshotter = try? await RouteSnapshotter(route: pack.route, points: pack.points),
                      let image = try? await snapshotter.take() else { continue }
                await renderer.addPage(with: image)
            }
            let url = await renderer.finalize()
            return url
        }
    }
}

extension HeadquarterDistrictDetailFeature.State {
    var isExportLoading: Bool {
        activeExportKind != nil
    }
    
    var isSubmissionExportLoading: Bool {
        activeExportKind == .submission
    }
    
    var isTableExportLoading: Bool {
        activeExportKind == .table
    }

    var displayedOrder: Int {
        get { district.order + 1 }
        set { district.order = max(0, newValue - 1) }
    }
}

extension HeadquarterDistrictDetailFeature.Destination.State: Equatable {}
extension HeadquarterDistrictDetailFeature.Destination.Action: Equatable {}
