//
//  DistrictManagementReducer.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/03/06.
//

//state 共通
import ComposableArchitecture
import PhotosUI
import _PhotosUI_SwiftUI

@Reducer
struct AdminDistrictEditFeature{
    
    @Dependency(\.apiClient) var apiClient
    @Dependency(\.accessToken) var accessToken
    
    @Reducer
    enum Destination {
        case base(AdminBaseFeature)
        case area(AdminAreaFeature)
        case performance(AdminPerformanceFeature)
    }
    
    @ObservableState
    struct State: Equatable{
        var item: District
        var image: PhotosPickerItem?
        var isLoading: Bool = false
        @Presents var destination: Destination.State?
        @Presents var alert: OkAlert.State?
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
        case performanceDeleteTapped(Performance)
        case postReceived(Result<String,ApiError>)
        case destination(PresentationAction<Destination.Action>)
        case alert(PresentationAction<OkAlert.Action>)
    }
    
    var body: some ReducerOf<AdminDistrictEditFeature>{
        BindingReducer()
        Reduce{ state, action in
            switch action {
            case .binding:
                return .none
            case .cancelTapped:
                return .none
            case .saveTapped:
                state.isLoading = true
                return .run{ [item = state.item] send in
                    if let token = accessToken.value{
                        let result = await apiClient.putDistrict(item, token)
                        await send(.postReceived(result))
                    }else{
                        await send(.postReceived(.failure(ApiError.unknown("No Access Token"))))
                    }
                }
            case .baseTapped:
                state.destination = .base(AdminBaseFeature.State(coordinate: state.item.base))
                return .none
            case .areaTapped:
                state.destination = .area(AdminAreaFeature.State(coordinates: state.item.area))
                return .none
            case .performanceAddTapped:
                state.destination = .performance(AdminPerformanceFeature.State())
                return .none
            case .performanceEditTapped(let item):
                state.destination = .performance(AdminPerformanceFeature.State(item: item))
                return .none
            case .performanceDeleteTapped(let item):
                state.item.performances.removeAll(where: { $0.id == item.id })
                return .none
            case .postReceived(let result):
                state.isLoading = false
                if case let .failure(error) = result {
                    state.alert = OkAlert.make("保存に失敗しました。\(error.localizedDescription)")
                }
                return .none
            case .destination(.presented(let childAction)):
                switch childAction {
                case .base(.doneTapped):
                    if case let .base(baseState) = state.destination {
                        state.item.base = baseState.coordinate
                    }
                    state.destination = nil
                    return .none
                case .area(.doneTapped):
                    if case let .area(areaState) = state.destination {
                        state.item.area = areaState.coordinates
                    }
                    state.destination = nil
                    return .none
                case .performance(.doneTapped):
                    if case let .performance(performanceState) = state.destination {
                        state.item.performances.upsert(performanceState.item)
                    }
                    state.destination = nil
                    return .none
                case .performance(.cancelTapped):
                    state.destination = nil
                    return .none
                default:
                    return .none
                }
            case .destination(_):
                return .none
            case .alert(.presented(.okTapped)):
                state.alert = nil
                return .none
            case .alert(_):
                return .none
            }
        }
        .ifLet(\.$destination, action: \.destination)
        .ifLet(\.$alert, action: \.alert)
    }
}

extension AdminDistrictEditFeature.Destination.State: Equatable {}
extension AdminDistrictEditFeature.Destination.Action: Equatable {}

//            case .binding(\.image):
//                guard let item = state.selectedItem else { return .none }
//                return .run { send in
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
