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
        var url: URL? = nil
    }
    
    @CasePathable
    enum Action: Equatable, BindableAction {
        case binding(BindingAction<State>)
        case editTapped
        case routeSelected(RouteSlot)
        case batchExportTapped
        case updateCompleted
        case routePrepared(RouteEntry)
        case batchExportPrepared(URL)
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
                defer {
                    state.isEditable.toggle()
                }
                if state.isEditable {
                    state.isLoading = true
                    return .run { [state] send in
                        let result = await task{ try await dataFetcher.update(district: state.district) }
                        switch result {
                        case .success(_):
                            await send(.updateCompleted)
                        case .failure(let error):
                            await send(.errorCaught(error))
                        }
                    }
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
                return batchExportEffect(state.routes, path: "\(state.district.name).pdf")
            case .updateCompleted:
                state.isLoading = false
                return .none
            case .routePrepared(let entry):
                state.isLoading = false
                state.destination = .route(.init(mode: .preview, route: entry.route, district: state.district, period: entry.period))
                return .none
            case .batchExportPrepared(let url):
                state.isLoading = false
                state.url = url
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
    
    func batchExportEffect(_ items: [RouteSlot], path: String) -> Effect<Action> {
        .run { send in
            //非同期並列にするとBEでアクセス過多
            let result = await task({
                let renderer = await PDFRenderer(path: path)
                for item in items {
                    guard let route = item.route,
                          let _ = try? await routeDataFetcher.fetch(routeID: route.id),
                          let snapshotter = await RouteSnapshotter(route),
                          let image = try? await snapshotter.take() else { continue }
                    await renderer.addPage(with: image)
                }
                let url = await renderer.finalize()
                return url
            }, defaultError: APIError.unknown(message: ""))
            switch result {
            case .success(let url):
                await send(.batchExportPrepared(url))
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

