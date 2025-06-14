//
//  AdminRegionInfoFeature.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/04/17.
//

import ComposableArchitecture

@Reducer
struct AdminRegionEdit {
    
    @Dependency(\.apiClient) var apiClient
    @Dependency(\.accessToken) var accessToken
    
    @ObservableState
    struct State: Equatable {
        var item: Region
        @Presents var span: AdminSpanEdit.State?
        @Presents var alert: OkAlert.State?
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
        case span(PresentationAction<AdminSpanEdit.Action>)
        case alert(PresentationAction<OkAlert.Action>)
    }
    
    var body: some ReducerOf<AdminRegionEdit> {
        BindingReducer()
        Reduce{ state, action in
            switch action {
            case .binding:
                return .none
            case .saveTapped:
                return .run { [region = state.item] send in
                    if let token = accessToken.value{
                        let result = await apiClient.putRegion(region, token)
                        await send(.received(result))
                    }else{
                        await send(.received(.failure(ApiError.unauthorized("アクセストークンが存在しません。"))))
                    }
                }
            case .cancelTapped:
                return .none
            case .received(.success(_)):
                return .none
            case .received(.failure(let error)):
                state.alert = OkAlert.error("保存に失敗しました。\(error.localizedDescription)")
                return .none
            case .onSpanEdit(let item):
                state.span = AdminSpanEdit.State(item)
                return .none
            case .onSpanDelete(let item):
                state.item.spans.removeAll(where: {$0.id == item.id})
                return .none
            case .onSpanAdd:
                state.span = AdminSpanEdit.State()
                return .none
            case .span(.presented(.doneTapped)):
                if let span = state.span?.span {
                    state.item.spans.upsert(span)
                    state.item.spans.sort()
                }
                state.span = nil
                return .none
            case .span(.presented(.cancelTapped)):
                state.span = nil
                return .none
            case .span(_):
                return .none
            case .alert(.presented(.okTapped)):
                state.alert = nil
                return .none
            case .alert(_):
                return .none
            }
        }
        .ifLet(\.$span, action: \.span){
            AdminSpanEdit()
        }
        .ifLet(\.$alert, action: \.alert)
    }
}
