//
//  HeadquarterDistrictListFeature.swift
//  MaTool
//
//  Created by 松下和也 on 2025/05/12.
//

import ComposableArchitecture
import Foundation
import Shared
import SQLiteData

@Reducer
struct HeadquarterDistrictListFeature {
    
    @Reducer
    enum Destination {
        case detail(HeadquarterDistrictDetailFeature)
        case create(DistrictCreateFeature)
    }
    
    @ObservableState
    struct State: Equatable {
        @FetchOne var festival: Festival
        @FetchAll var rawDistricts: [District]
        var districts: [District] { rawDistricts.sorted() }
        
        var isLoading: Bool = false
        var folder: ExportedFolder? = nil
        @Presents var destination: Destination.State?
        @Presents var alert: AlertFeature.State?
    }
    
    enum Action: Equatable, BindableAction {
        case binding(BindingAction<State>)
        case selected(District)
        case createTapped
        case batchExportTapped
        case selectedReceived(TaskResult<District>)
        case batchExportReceived(TaskResult<[URL]>)
        case destination(PresentationAction<Destination.Action>)
        case alert(PresentationAction<AlertFeature.Action>)
    }
    
    @Dependency(DistrictDataFetcherKey.self) var dataFetcher
    @Dependency(RouteDataFetcherKey.self) var routeDataFetcher
    
    var body: some ReducerOf<HeadquarterDistrictListFeature> {
        BindingReducer()
        Reduce{ state, action in
            switch action {
            case .binding:
                return .none
            case .selected(let district):
                state.isLoading = true
                return .task(Action.selectedReceived) {
                    try await dataFetcher.fetch(districtID: district.id)
                    return district
                }
            case .createTapped:
                state.destination = .create(.init(festivalId: state.festival.id))
                return .none
            case .batchExportTapped:
                return batchExportEffect(state)
            case .selectedReceived(.success(let district)):
                state.isLoading = false
                state.destination = .detail(.init(district))
                return .none
            case .batchExportReceived(.success(let urls)):
                state.folder = .init(urls)
                return .none
            case .selectedReceived(.failure(let error)),
                .batchExportReceived(.failure(let error)):
                state.isLoading = false
                state.alert = AlertFeature.error(error.localizedDescription)
                return .none
            case .destination:
                return .none
            case .alert:
                return .none
            }
        }
        .ifLet(\.$destination, action: \.destination)
        .ifLet(\.$alert, action: \.alert)
    }
    
    func batchExportEffect(_ state: State) -> Effect<Action> {
        .task(Action.batchExportReceived) {
            var urls: [URL] = []
            //非同期並列にするとBEでアクセス過多
            for district in state.districts {
                let renderer = await PDFRenderer(path: "\(district.name).pdf")
                guard let _ =  try? await routeDataFetcher.fetchAll(districtID: district.id, query: .latest) else { continue }
                let routes: [Route] = FetchAll(Route.where { $0.districtId == district.id }).wrappedValue
                if routes.isEmpty { continue }
                for route in routes {
                    guard (try? await routeDataFetcher.fetch(routeID: route.id)) != nil,
                          let snapshotter = try? await RouteSnapshotter(route),
                          let image = try? await snapshotter.take() else { continue }
                    await renderer.addPage(with: image)
                }
                let url = await renderer.finalize()
                urls.append(url)
            }
            return urls
        }
    }
}

extension HeadquarterDistrictListFeature.Destination.State: Equatable {}
extension HeadquarterDistrictListFeature.Destination.Action: Equatable {}

extension HeadquarterDistrictListFeature.State{
    init(_ festival: Festival){
        self._festival = FetchOne(wrappedValue: festival, Festival.find(festival.id))
        self._rawDistricts = FetchAll(District.where{ $0.festivalId == festival.id })
    }
}
