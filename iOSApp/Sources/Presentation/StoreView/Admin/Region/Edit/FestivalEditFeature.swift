//
//  AdminFestivalInfoFeature.swift
//  MaTool
//
//  Created by 松下和也 on 2025/04/17.
//

import Foundation
import ComposableArchitecture
import Shared

@Reducer
struct FestivalEditFeature {
    
    @Reducer
    enum Destination {
        case checkpoint(CheckpointEditFeature)
        case hazard(HazardSectionFeature)
    }
    
    @ObservableState
    struct State: Equatable {
        var item: Festival
        var isLoading: Bool = false
        @Presents var destination: Destination.State?
        @Presents var alert: Alert.State?
    }
    
    @CasePathable
    enum Action: Equatable, BindableAction {
        case binding(BindingAction<State>)
        case saveTapped
        case cancelTapped
        case putReceived(Result<Festival, APIError>)
        case onCheckpointEdit(Checkpoint)
        case onCheckpointAdd
        case hazardTapped(HazardSection)
        case hazardCreateTapped
        case destination(PresentationAction<Destination.Action>)
        case alert(PresentationAction<Alert.Action>)
    }
    
    @Dependency(\.apiRepository) var apiRepository
    @Dependency(\.dismiss) var dismiss
    
    var body: some ReducerOf<FestivalEditFeature> {
        BindingReducer()
        Reduce{ state, action in
            switch action {
            case .binding:
                return .none
            case .saveTapped:
                state.isLoading = true
                return .run { [festival = state.item] send in
                    let result = await apiRepository.putFestival(festival)
                    await send(.putReceived(result))
                }
            case .cancelTapped:
                return .run { _ in
                    await dismiss()
                }
            case .putReceived(let result):
                state.isLoading = false
                if case let .failure(error) = result {
                    state.alert = Alert.error("保存に失敗しました。\(error.localizedDescription)")
                }
                return .none
            case .onCheckpointEdit(let item):
                state.destination = .checkpoint(
                    CheckpointEditFeature.State(
                        title: "経由地",
                        item: item
                    )
                )
                return .none
            case .onCheckpointAdd:
                state.destination = .checkpoint(
                    CheckpointEditFeature.State(
                        title: "経由地",
                        item: Checkpoint(
                            id: UUID().uuidString
                        )
                    )
                )
                return .none
            case .hazardTapped(let hazard):
                let mapRegion = {
                    if hazard.coordinates.isEmpty{ makeRegion(origin: state.item.base, spanDelta: spanDelta) }
                    else { makeRegion(hazard.coordinates) }
                }()
                state.destination = .hazard(.init(hazard, mapRegion: mapRegion))
                return .none
            case .hazardCreateTapped:
                state.destination = .hazard(.init(mapRegion: makeRegion(origin: state.item.base, spanDelta: spanDelta)))
                return .none
            case .destination(.presented(.checkpoint(.doneTapped))):
                guard let item = state.destination?.checkpoint?.item else { return .none }
                state.item.checkpoints.upsert(item)
                state.destination = nil
                return .none
            case .destination(.presented(.hazard(.doneTapped))):
                guard state.destination?.hazard?.isValid ?? false,
                    let item = state.destination?.hazard?.item else { return .none }
                state.item.hazardSections.upsert(item)
                state.destination = nil
                return .none
            case .destination(.presented(.hazard(.deleteTapped))):
                guard let item = state.destination?.hazard?.item else { return .none }
                state.item.hazardSections.removeAll(of: item)
                state.destination = nil
                return .none
            case .alert(.presented(.okTapped)):
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

extension FestivalEditFeature.Destination.State: Equatable{}
extension FestivalEditFeature.Destination.Action: Equatable{}
