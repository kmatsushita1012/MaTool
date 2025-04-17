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
struct DistrictAdminFeature{
    
    @Dependency(\.remoteClient) var remoteClient
    
    @Reducer
    enum Destination {
        case base(BaseAdminFeature)
        case area(AreaAdminFeature)
        case performance(PerformanceAdminFeature)
    }
    
    @ObservableState
    struct State: Equatable{
        var item: District
        var image: PhotosPickerItem?
        @Presents var destination: Destination.State?
    }

    enum Action: BindableAction {
        case binding(BindingAction<State>)
        case cancelButtonTapped
        case saveButtonTapped
        case received(Result<String,RemoteError>)
        case baseButtonTapped
        case areaButtonTapped
        case performanceAddButtonTapped
        case performanceEditButtonTapped(Performance)
        case performanceDeleteButtonTapped(Performance)
        case destination(PresentationAction<Destination.Action>)
    }
    
    var body: some ReducerOf<DistrictAdminFeature>{
        BindingReducer()
        Reduce{ state, action in
            switch action {
            case .binding:
                return .none
            case .cancelButtonTapped:
                return .none
            case .saveButtonTapped:
                return .run{ [item = state.item] send in
                    let result = await remoteClient.postDistrict(item, "")
                    await send(.received(result))
                }
            case .received(_):
                //TODO dismiss
                return .none
            case .baseButtonTapped:
                state.destination = .base(BaseAdminFeature.State(coordinate: state.item.base))
                return .none
            case .areaButtonTapped:
                state.destination = .area(AreaAdminFeature.State(coordinates: state.item.area))
                return .none
            case .performanceAddButtonTapped:
                state.destination = .performance(PerformanceAdminFeature.State())
                return .none
            case .performanceEditButtonTapped(let item):
                state.destination = .performance(PerformanceAdminFeature.State(item: item))
                return .none
            case .performanceDeleteButtonTapped(let item):
                state.item.performances.removeAll(where: { $0.id == item.id })
                return .none
            case .destination(.presented(.base(.doneButtonTapped))):
                if case let .base(baseState) = state.destination {
                    state.item.base = baseState.coordinate
                }
                state.destination = nil
                return .none
            case .destination(.presented(.area(.doneButtonTapped))):
                if case let .area(areaState) = state.destination {
                    state.item.area = areaState.coordinates
                }
                state.destination = nil
                return .none
            case .destination(.presented(.performance(.doneButtonTapped))):
                if case let .performance(performanceState) = state.destination {
                    state.item.performances.upsert(performanceState.item)
                }
                state.destination = nil
                return .none
            case .destination(.presented(.performance(.cancelButtonTapped))):
                state.destination = nil
                return .none
            case .destination(_):
                return .none
            }
        }
        .ifLet(\.$destination, action: \.destination)
    }
}

extension DistrictAdminFeature.Destination.State: Equatable {}

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
