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
    }
    
    @ObservableState
    struct State: Equatable {
        var district: District
        @FetchAll var routes: [RouteSlot]
        
        var isEditable: Bool = false
        var isLoading: Bool = false
        
        @Presents var destination: Destination.State?
        @Presents var alert: Alert.State?
        var folder: ExportedFolder? = nil
    }
    
    @CasePathable
    enum Action: Equatable, BindableAction {
        case binding(BindingAction<State>)
        case editTapped
        case routeSelected(RouteSlot)
        case batchExportTapped
        case routePrepared(RouteEntry)
        case batchExportPrepared([URL])
        case errorCaught(APIError)
        case destination(PresentationAction<Destination.Action>)
        case alert(PresentationAction<Alert.Action>)
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
                state.isEditable.toggle()
                if state.isEditable {
                    state.isLoading = true
                    return .none
                    // TODO: API開通待ち
//                    return .run { [state] send in
//                        let result = await task{ try await dataFetcher.update(district: state.district, performances: ) }
//                    }
                } else {
                    return .none
                }
            case .routeSelected(let slot):
                guard let route = slot.route else { return .none }
                state.isLoading = true
                let entry: RouteEntry = .init(period: slot.period, route: route)
                return .run { send in
                    let result = await task{ try await routeDataFetcher.fetch(routeID: route.id) }
                    switch result {
                    case .success:
                        await send(.routePrepared(entry))
                    case .failure(let error):
                        await send(.errorCaught(error))
                    }
                }
            case .batchExportTapped:
                state.isLoading = true
                return batchExportEffect(state.routes)
            case .routePrepared(let entry):
                state.isLoading = false
                state.destination = .route(.init(mode: .preview, route: entry.route, district: state.district, period: entry.period))
                return .none
            case .batchExportPrepared(let urls):
                state.folder = .init(urls)
                return .none
            case .errorCaught(let error):
                state.isLoading = false
                state.alert = Alert.error(error.localizedDescription)
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
    
    func batchExportEffect(_ items: [RouteSlot]) -> Effect<Action> {
        .run { send in
            //非同期並列にするとBEでアクセス過多
            let result = await task({
                var urls: [URL] = []
                for item in items {
                    guard let route = item.route,
                          let _ = try? await routeDataFetcher.fetch(routeID: route.id),
                          let snapshotter = await RouteSnapshotter(route),
                          let image = try? await snapshotter.take(),
                          let url = await snapshotter.createPDF(with: image, path: "") else { continue } //FIXME
                    urls.append(url)
                }
                return urls
            }, defaultError: APIError.unknown(message: ""))
            switch result {
            case .success(let urls):
                await send(.batchExportPrepared(urls))
            case .failure(let error):
                await send(.errorCaught(error))
            }
        }
    }
}

extension HeadquarterDistrictDetailFeature.Destination.State: Equatable {}
extension HeadquarterDistrictDetailFeature.Destination.Action: Equatable {}

extension HeadquarterDistrictDetailFeature.State {
    init(_ district: District) {
        self.district = district
        self._routes = FetchAll(districtId: district.id, latest: true)
    }
    
}

