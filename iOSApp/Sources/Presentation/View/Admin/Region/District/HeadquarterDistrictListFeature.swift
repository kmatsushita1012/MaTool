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
        @FetchAll var districts: [District]
        var draftDistricts: [District]? = nil
        var isReordering: Bool = false
        var searchText: String = ""
        
        var isLoading: Bool = false
        var folder: ExportedFolder? = nil
        @Presents var destination: Destination.State?
        @Presents var alert: AlertFeature.State?
    }
    
    enum Action: Equatable, BindableAction {
        case binding(BindingAction<State>)
        case selected(District)
        case createTapped
        case reorderTapped
        case districtMoved(from: IndexSet, to: Int)
        case reorderReceived(VoidTaskResult)
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
            case .binding(\.searchText):
                if state.isReordering {
                    state.searchText = ""
                }
                return .none
            case .binding:
                return .none
            case .selected(let district):
                state.isLoading = true
                return .task(Action.selectedReceived) {
                    async let districtFetch: Void = dataFetcher.fetch(districtID: district.id)
                    async let routeFetch: Void = routeDataFetcher.fetchAll(districtID: district.id, query: .latest)
                    _ = try await (districtFetch, routeFetch)
                    return district
                }
            case .createTapped:
                state.destination = .create(.init(festivalId: state.festival.id))
                return .none
            case .reorderTapped:
                if state.isReordering {
                    let changed = changedDistricts(state)
                    guard !changed.isEmpty else {
                        state.isReordering = false
                        state.draftDistricts = nil
                        return .none
                    }
                    state.isLoading = true
                    return .task(Action.reorderReceived) {
                        for district in changed {
                            try await dataFetcher.update(district: district)
                        }
                    }
                } else {
                    guard state.searchText.isEmpty else { return .none }
                    state.draftDistricts = state.districts.sorted()
                    state.isReordering = true
                    return .none
                }
            case let .districtMoved(from: source, to: destination):
                guard var draftDistricts = state.draftDistricts else { return .none }
                let orders = draftDistricts.map(\.order)
                draftDistricts.move(fromOffsets: source, toOffset: destination)
                for index in draftDistricts.indices {
                    draftDistricts[index].order = orders[index]
                }
                state.draftDistricts = draftDistricts
                return .none
            case .reorderReceived(.success):
                state.isLoading = false
                state.isReordering = false
                state.draftDistricts = nil
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
                .reorderReceived(.failure(let error)),
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
                let routes: [Route] = FetchAll(Route.where { $0.districtId.eq(district.id) }).wrappedValue
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
        self._festival = FetchOne(festival)
        self._districts = FetchAll(festivalId: festival.id)
    }
}

private extension HeadquarterDistrictListFeature {
    func changedDistricts(_ state: State) -> [District] {
        guard let draftDistricts = state.draftDistricts else { return [] }
        let orderMap = Dictionary(uniqueKeysWithValues: state.districts.map { ($0.id, $0.order) })
        return draftDistricts.filter { district in
            orderMap[district.id] != district.order
        }
    }
}

extension HeadquarterDistrictListFeature.State {
    var filteredDistricts: [District] {
        let source: [District]
        if isReordering {
            source = draftDistricts ?? districts.sorted()
        } else {
            source = districts.sorted()
        }
        guard !searchText.isEmpty else { return source }
        return source.filter { $0.name.contains(searchText) }
    }
    
    var isReorderDisabled: Bool {
        !isReordering && !searchText.isEmpty
    }
}
