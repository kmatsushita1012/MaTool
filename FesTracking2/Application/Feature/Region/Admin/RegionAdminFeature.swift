//
//  RegionAdminFeature.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/04/17.
//

import ComposableArchitecture

@Reducer
struct RegionAdminFeature {
    @ObservableState
    struct State: Equatable {
        var item: Region
        @Presents var span: SpanAdminFeature.State?
    }
    @CasePathable
    enum Action: BindableAction {
        case binding(BindingAction<State>)
        case saveButtonTapped
        case cancelButtonTapped
        case onSpanEdit(Span)
        case onSpanDelete(Span)
        case onSpanAdd
        case span(PresentationAction<SpanAdminFeature.Action>)
    }
    var body: some ReducerOf<RegionAdminFeature> {
        BindingReducer()
        Reduce{ state, action in
            switch action {
            case .binding:
                return .none
            case .saveButtonTapped:
                return .none
            case .cancelButtonTapped:
                return .none
            case .onSpanEdit(let item):
                state.span = SpanAdminFeature.State(item)
                return .none
            case .onSpanDelete(let item):
                state.item.spans.removeAll(where: {$0.id == item.id})
                return .none
            case .onSpanAdd:
                state.span = SpanAdminFeature.State()
                return .none
            case .span(.presented(.doneButtonTapped)):
                if let span = state.span?.span {
                    state.item.spans.upsert(span)
                    state.item.spans.sort()
                }
                state.span = nil
                return .none
            case .span(.presented(.cancelButtonTapped)):
                print(state.item.spans)
                state.span = nil
                return .none
            case .span(_):
                return .none
            }
        }
        .ifLet(\.$span, action: \.span){
            SpanAdminFeature()
        }
    }
}
