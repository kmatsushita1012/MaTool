//
//  DistrictManagementReducer.swift
//  MaTool
//
//  Created by 松下和也 on 2025/03/06.
//

//state 共通
import ComposableArchitecture
import Shared

@Reducer
struct AdminDistrictEdit {
    
    @Reducer
    enum Destination {
        case base(AdminBaseEdit)
        case area(AdminAreaEdit)
        case performance(AdminPerformanceEdit)
    }
    
    @ObservableState
    struct State: Equatable{
        var item: District
//        var image: PhotosPickerItem?
        var isLoading: Bool = false
        let tool: DistrictTool
        @Presents var destination: Destination.State?
        @Presents var alert: Alert.State?
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
        case postReceived(Result<District,APIError>)
        case destination(PresentationAction<Destination.Action>)
        case alert(PresentationAction<Alert.Action>)
    }
    
    @Dependency(\.authService) var authService
    @Dependency(\.apiRepository) var apiRepository
    @Dependency(\.dismiss) var dismiss
    
    var body: some ReducerOf<AdminDistrictEdit>{
        BindingReducer()
        Reduce{ state, action in
            switch action {
            case .binding:
                return .none
            case .cancelTapped:
                return .run { _ in
                    await dismiss()
                }
            case .saveTapped:
                state.isLoading = true
                return .run{ [item = state.item] send in
                    let result = await apiRepository.putDistrict(item)
                    await send(.postReceived(result))
                }
            case .baseTapped:
                if let base = state.item.base{
                    state.destination = .base(AdminBaseEdit.State(base: base))
                } else {
                    state.destination = .base(AdminBaseEdit.State(origin: state.tool.base))
                }
                return .none
            case .areaTapped:
                state.destination = .area(
                    AdminAreaEdit.State(
                        coordinates: state.item.area,
                        origin: state.item.base ?? state.tool.base
                    )
                )
                return .none
            case .performanceAddTapped:
                state.destination = .performance(AdminPerformanceEdit.State())
                return .none
            case .performanceEditTapped(let item):
                state.destination = .performance(AdminPerformanceEdit.State(item: item))
                return .none
            case .postReceived(let result):
                state.isLoading = false
                if case let .failure(error) = result {
                    state.alert = Alert.error("保存に失敗しました。\(error.localizedDescription)")
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

                case .performance(.deleteTapped):
                    if case let .performance(performanceState) = state.destination {
                        state.item.performances.removeAll(where: { $0.id == performanceState.item.id })
                    }
                    state.destination = nil
                    return .none
                case .base,
                    .area,
                    .performance:
                    return .none
                }
            case .destination(.dismiss):
                return .none
            case .alert:
                state.alert = nil
                return .none
            }
        }
        .ifLet(\.$destination, action: \.destination)
        .ifLet(\.$alert, action: \.alert)
    }
}

extension AdminDistrictEdit.Destination.State: Equatable {}
extension AdminDistrictEdit.Destination.Action: Equatable {}

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
