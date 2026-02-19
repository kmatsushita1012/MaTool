//
//  DistrictManagementReducer.swift
//  MaTool
//
//  Created by 松下和也 on 2025/03/06.
//

//state 共通
import ComposableArchitecture
import Shared
import SQLiteData

@Reducer
struct DistrictEditFeature {
    
    @Reducer
    enum Destination {
        case base(DistrictBaseEditFeature)
        case area(DistrictAreaEditFeature)
        case performance(PerformanceEditFeature)
    }
    
    @ObservableState
    struct State: Equatable{
        var district: District
        var performances: [Performance]
        
        var isLoading: Bool = false
        @Presents var destination: Destination.State?
        @Presents var alert: AlertFeature.State?
        @FetchOne var base: Coordinate
    }
    
    @CasePathable
    enum Action: BindableAction, Equatable {
        case binding(BindingAction<State>)
        case cancelTapped
        case saveTapped
        case baseTapped
        case areaTapped
        case performanceAddTapped
        case performanceEditTapped(Performance)
        case postReceived(VoidTaskResult)
        case destination(PresentationAction<Destination.Action>)
        case alert(PresentationAction<AlertFeature.Action>)
    }
    
    @Dependency(\.authService) var authService
    @Dependency(DistrictDataFetcherKey.self) var dataFetcher
    @Dependency(\.dismiss) var dismiss
    
    var body: some ReducerOf<DistrictEditFeature>{
        BindingReducer()
        Reduce{ state, action in
            switch action {
            case .binding:
                return .none
            case .cancelTapped:
                return .dismiss
            case .saveTapped:
                state.isLoading = true
                return .task(Action.postReceived) { [state] in
                    try await dataFetcher.update(district: state.district, performances: state.performances)
                    await dismiss()
                }
            case .baseTapped:
                if let base = state.district.base{
                    state.destination = .base(DistrictBaseEditFeature.State(base: base))
                } else {
                    state.destination = .base(DistrictBaseEditFeature.State(origin: state.base))
                }
                return .none
            case .areaTapped:
                state.destination = .area(
                    DistrictAreaEditFeature.State(
                        coordinates: state.district.area,
                        origin: state.district.base ?? state.base
                    )
                )
                return .none
            case .performanceAddTapped:
                state.destination = .performance(PerformanceEditFeature.State(districtId: state.district.id))
                return .none
            case .performanceEditTapped(let item):
                state.destination = .performance(PerformanceEditFeature.State(item: item))
                return .none
            case .postReceived(.failure(let error)):
                state.isLoading = false
                    state.alert = AlertFeature.error("保存に失敗しました。\(error.localizedDescription)")
                return .none
            case .destination(.presented(let childAction)):
                switch childAction {
                case .base(.doneTapped):
                    if let coordinate = state.destination?.base?.coordinate {
                        state.district.base = coordinate
                    }
                    state.destination = nil
                    return .none
                case .area(.doneTapped):
                    if let coordinates = state.destination?.area?.coordinates {
                        state.district.area = coordinates
                    }
                    state.destination = nil
                    return .none
                case .performance(.doneTapped):
                    if let item = state.destination?.performance?.item {
                        state.performances.upsert(item)
                    }
                    state.destination = nil
                    return .none

                case .performance(.deleteTapped):
                    if let item = state.destination?.performance?.item {
                        state.performances.removeAll(where: { $0.id == item.id })
                    }
                    state.destination = nil
                    return .none
                case .base,
                    .area,
                    .performance:
                    return .none
                }
            case .alert:
                state.alert = nil
                return .none
            default:
                return .none
            }
        }
        .ifLet(\.$destination, action: \.destination)
        .ifLet(\.$alert, action: \.alert)
    }
}

extension DistrictEditFeature.Destination.State: Equatable {}
extension DistrictEditFeature.Destination.Action: Equatable {}

extension DistrictEditFeature.State {
    init(_ district: District) {
        self.district = district
        self.performances = FetchAll(Performance.where{ $0.districtId == district.id }).wrappedValue
        self._base = FetchOne(wrappedValue: .init(latitude: 0, longitude: 0), Festival.where{ $0.id == district.festivalId }.select(\.base))
    }
}

//            case .binding(\.image):
//                guard let item = state.selectedItem else { return .none }
//                return .task { send in
//                    do {
//                        let data = try await item.loadTransferable(type: Data.self)
//                        if let data, let uiImage = UIImage(data: data) {
//                            await send(.loadImage(.success(uiImage)))
//                        } else {
//                            await send(.loadImage(.failure(ImageError.failedToLoad)))
//                        }
//                    } catch {
//                        await send(.loadImage(.failure(error)))
//                    }
//                }
