//
//  HeadquarterDistrictDetailFeature.swift
//  MaTool
//
//  Created by 松下和也 on 2026/01/24.
//

import ComposableArchitecture
import SQLiteData
import Shared
import Foundation

@Reducer
struct HeadquarterDistrictDetailFeature {
    
    @Reducer
    enum Destination {
        case route(RouteEditFeature)
        case reissue(DistrictReissueFeature)
    }
    
    @ObservableState
    struct State: Equatable {
        var district: District
        var routes: [RouteSlot]
        fileprivate var originalRoutes: [Route.ID: Route] = [:]
        var routeDrafts: [Route.ID: RouteDraft] = [:]
        
        var isEditable: Bool = false
        var isLoading: Bool = false
        
        @Presents var destination: Destination.State?
        @Presents var alert: AlertFeature.State?
        var url: URL? = nil
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
        case updateReceived(VoidAppResult)
        case routeReceived(AppResult<RouteEntry>)
        case batchExportReceived(AppResult<URL>)
        case destination(PresentationAction<Destination.Action>)
        case alert(PresentationAction<AlertFeature.Action>)
    }
    
    @Dependency(DistrictDataFetcherKey.self) var dataFetcher
    @Dependency(RouteDataFetcherKey.self) var routeDataFetcher
    
    var body: some ReducerOf<HeadquarterDistrictDetailFeature> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .binding(_):
                return .none
            case .editTapped:
                defer {
                    state.isEditable.toggle()
                }
                if state.isEditable {
                    state.isLoading = true
                    return .task(Action.updateReceived) { [state] in
                        try await dataFetcher.update(district: state.district)
                    }
                } else {
                    return .none
                }
            case .reissueTapped:
                state.destination = .reissue(.init(district: state.district))
                return .none
            case .routeSelected(let slot):
                guard let route = slot.route else { return .none }
                if let draft = state.routeDrafts[route.id] {
                    state.destination = try? { .route(try .init(mode: .preview, draft: draft)) }()
                    return .none
                }
                state.isLoading = true
                let entry: RouteEntry = .init(period: slot.period, route: route)
                return .task(Action.routeReceived) {
                    try await routeDataFetcher.fetch(routeID: route.id)
                    return entry
                }
            case .batchExportTapped:
                state.isLoading = true
                return exportEffect(state: state, path: "\(state.district.name).pdf", includesRouteMap: true)
            case .tableExportTapped:
                state.isLoading = true
                return exportEffect(state: state, path: "\(state.district.name)_行動表.pdf", includesRouteMap: false)
            case .resetDraftsTapped:
                guard !state.routeDrafts.isEmpty else { return .none }
                let draftIDs = Set(state.routeDrafts.keys)
                state.routeDrafts = [:]
                for index in state.routes.indices {
                    guard let route = state.routes[index].route,
                          draftIDs.contains(route.id),
                          let originalRoute = state.originalRoutes[route.id] else { continue }
                    state.routes[index] = RouteSlot(period: state.routes[index].period, route: originalRoute)
                }
                return .none
            case .updateReceived(.success):
                state.isLoading = false
                return .none
            case .routeReceived(.success(let entry)):
                state.isLoading = false
                state.destination = try? { .route(try .init(mode: .preview, route: entry.route)) }()
                return .none
            case .destination(.presented(.route(.delegate(.applied(let draft))))):
                state.routeDrafts[draft.route.id] = draft
                if let index = state.routes.firstIndex(where: { $0.route?.id == draft.route.id }) {
                    let slot = state.routes[index]
                    state.routes[index] = RouteSlot(period: slot.period, route: draft.route)
                }
                return .none
            case .batchExportReceived(.success(let url)):
                state.isLoading = false
                state.url = url
                return .none
            case .updateReceived(.failure(let error)),
                .routeReceived(.failure(let error)),
                .batchExportReceived(.failure(let error)):
                state.isLoading = false
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
            var passagesByRouteID: [Route.ID: [RoutePassage]] = [:]
            var pointsByRouteID: [Route.ID: [Point]] = [:]
            var resolvedRoutesByRouteID: [Route.ID: Route] = [:]
            for route in routes {
                if let draft = state.routeDrafts[route.id] {
                    passagesByRouteID[route.id] = draft.passages
                    pointsByRouteID[route.id] = draft.points
                    resolvedRoutesByRouteID[route.id] = draft.route
                    continue
                }
                do {
                    try await routeDataFetcher.fetch(routeID: route.id)
                    let passages: [RoutePassage] = FetchAll(routeId: route.id).wrappedValue
                    let points: [Point] = FetchAll(routeId: route.id).wrappedValue
                    passagesByRouteID[route.id] = passages
                    pointsByRouteID[route.id] = points
                    resolvedRoutesByRouteID[route.id] = route
                } catch {
                    continue
                }
            }
            let tableSnapshotter = await ActionTableSnapshotter(
                district: state.district,
                slots: state.routes,
                passagesByRouteID: passagesByRouteID
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
                let resolvedRoute = resolvedRoutesByRouteID[route.id] ?? route
                guard let points = pointsByRouteID[route.id],
                      let snapshotter = try? await RouteSnapshotter(route: resolvedRoute, points: points),
                      let image = try? await snapshotter.take() else { continue }
                await renderer.addPage(with: image)
            }
            let url = await renderer.finalize()
            return url
        }
    }
}

extension HeadquarterDistrictDetailFeature.Destination.State: Equatable {}
extension HeadquarterDistrictDetailFeature.Destination.Action: Equatable {}

extension HeadquarterDistrictDetailFeature.State {
    init(_ district: District) {
        let routes: [RouteSlot] = FetchAll(districtId: district.id, latest: true).wrappedValue
        self.district = district
        self.routes = routes
        self.originalRoutes = Dictionary(uniqueKeysWithValues: routes.compactMap {
            guard let route = $0.route else { return nil }
            return (route.id, route)
        })
    }
    
}
