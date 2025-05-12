//
//  AdminRegionInfoFeature.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/04/17.
//

import ComposableArchitecture

@Reducer
struct AdminRegionEditFeature {
    
    @Dependency(\.apiClient) var apiClient
    
    @ObservableState
    struct State: Equatable {
        var item: Region
        @Presents var span: AdminSpanFeature.State?
    }
    
    @CasePathable
    enum Action: Equatable, BindableAction {
        case binding(BindingAction<State>)
        case saveTapped
        case cancelTapped
        case received(Result<String, ApiError>)
        case onSpanEdit(Span)
        case onSpanDelete(Span)
        case onSpanAdd
        case span(PresentationAction<AdminSpanFeature.Action>)
    }
    
    var body: some ReducerOf<AdminRegionEditFeature> {
        BindingReducer()
        Reduce{ state, action in
            switch action {
            case .binding:
                return .none
            case .saveTapped:
                return .run { [region = state.item] send in
                    let result = await apiClient.putRegion(region,"")
                    await send(.received(result))
                }
            case .cancelTapped:
                return .none
            case .received(.success(_)):
                return .none
            case .received(.failure(_)):
                return .none
            case .onSpanEdit(let item):
                state.span = AdminSpanFeature.State(item)
                return .none
            case .onSpanDelete(let item):
                state.item.spans.removeAll(where: {$0.id == item.id})
                return .none
            case .onSpanAdd:
                state.span = AdminSpanFeature.State()
                return .none
            case .span(.presented(.doneButtonTapped)):
                if let span = state.span?.span {
                    state.item.spans.upsert(span)
                    state.item.spans.sort()
                }
                state.span = nil
                return .none
            case .span(.presented(.cancelButtonTapped)):
                state.span = nil
                return .none
            case .span(_):
                return .none
            }
        }
        .ifLet(\.$span, action: \.span){
            AdminSpanFeature()
        }
    }
}
