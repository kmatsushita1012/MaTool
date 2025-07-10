//
//  AdminRegionInfoFeature.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/04/17.
//

import Foundation
import ComposableArchitecture

@Reducer
struct AdminRegionEdit {
    
    @Dependency(\.apiRepository) var apiRepository
    @Dependency(\.authService) var authService
    
    @Reducer
    enum Destination {
        case span(AdminSpanEdit)
        case milestone(InformationEdit)
    }
    
    @ObservableState
    struct State: Equatable {
        var item: Region
        @Presents var destination: Destination.State?
        @Presents var alert: Alert.State?
    }
    
    @CasePathable
    enum Action: Equatable, BindableAction {
        case binding(BindingAction<State>)
        case saveTapped
        case cancelTapped
        case putReceived(Result<String, ApiError>)
        case onSpanEdit(Span)
        case onSpanAdd
        case onMilestoneEdit(Information)
        case onMilestoneDelete(Information)
        case onMilestoneAdd
        case destination(PresentationAction<Destination.Action>)
        case alert(PresentationAction<Alert.Action>)
    }
    
    var body: some ReducerOf<AdminRegionEdit> {
        BindingReducer()
        Reduce{ state, action in
            switch action {
            case .binding:
                return .none
            case .saveTapped:
                return .run { [region = state.item] send in
                    if let token = await authService.getAccessToken() {
                        let result = await apiRepository.putRegion(region, token)
                        await send(.putReceived(result))
                    }else{
                        await send(.putReceived(.failure(ApiError.unauthorized("認証に失敗しました。ログインし直してください"))))
                    }
                }
            case .cancelTapped:
                return .none
            case .putReceived(.success(_)):
                return .none
            case .putReceived(.failure(let error)):
                state.alert = Alert.error("保存に失敗しました。\(error.localizedDescription)")
                return .none
            case .onSpanEdit(let item):
                state.destination = .span(
                    AdminSpanEdit.State(item)
                )
                return .none
            case .onSpanAdd:
                state.destination = .span(AdminSpanEdit.State())
                return .none
            case .onMilestoneEdit(let item):
                state.destination = .milestone(
                    InformationEdit.State(
                        title: "経由地",
                        item: item
                    )
                )
                return .none
            case .onMilestoneDelete(let item):
                state.item.milestones.removeAll(where: {$0.id == item.id})
                return .none
            case .onMilestoneAdd:
                state.destination = .milestone(
                    InformationEdit.State(
                        title: "経由地",
                        item: Information(
                            id: UUID().uuidString
                        )
                    )
                )
                return .none
            case .destination(.presented(let action)):
                switch action {
                    case .span(.doneTapped):
                        if case let .span(spanState) = state.destination {
                            state.item.spans.upsert(spanState.span)
                            state.item.spans.sort()
                        }
                        state.destination = nil
                        return .none
                    case .milestone(.doneTapped):
                        if case let .milestone(milestoneState) = state.destination {
                            state.item.milestones.upsert(milestoneState.item)
                        }
                        state.destination = nil
                        return .none
                    case.span(.cancelTapped),
                        .milestone(.cancelTapped):
                        state.destination = nil
                        return .none
                    case .span(.alert(.presented(.okTapped))):
                        if case let .span(spanState) = state.destination {
                            state.item.spans.removeAll(where: {$0.id == spanState.span.id})
                        }
                        state.destination = nil
                        return .none
                    case .span,
                        .milestone:
                        return .none
                }
            case .destination:
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

extension AdminRegionEdit.Destination.State: Equatable{}
extension AdminRegionEdit.Destination.Action: Equatable{}
