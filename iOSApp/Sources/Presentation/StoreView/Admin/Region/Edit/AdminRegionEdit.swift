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
struct AdminFestivalEdit {
    
    @Reducer
    enum Destination {
        case checkpoint(InformationEdit)
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
        case onCheckpointDelete(Checkpoint)
        case onCheckpointAdd
        case destination(PresentationAction<Destination.Action>)
        case alert(PresentationAction<Alert.Action>)
    }
    
    @Dependency(\.apiRepository) var apiRepository
    @Dependency(\.dismiss) var dismiss
    
    var body: some ReducerOf<AdminFestivalEdit> {
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
                    InformationEdit.State(
                        title: "経由地",
                        item: item
                    )
                )
                return .none
            case .onCheckpointDelete(let item):
                state.item.checkpoints.removeAll(where: {$0.id == item.id})
                return .none
            case .onCheckpointAdd:
                state.destination = .checkpoint(
                    InformationEdit.State(
                        title: "経由地",
                        item: Checkpoint(
                            id: UUID().uuidString
                        )
                    )
                )
                return .none
            case .destination(.presented(let action)):
                switch action {
                    case .checkpoint(.doneTapped):
                        if case let .checkpoint(checkpointState) = state.destination {
                            state.item.checkpoints.upsert(checkpointState.item)
                        }
                        state.destination = nil
                        return .none
                    case .checkpoint(.cancelTapped):
                        state.destination = nil
                        return .none
                    case .checkpoint:
                        return .none
                }
            case .destination(.dismiss):
                state.destination = nil
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

extension AdminFestivalEdit.Destination.State: Equatable{}
extension AdminFestivalEdit.Destination.Action: Equatable{}
