//
//  AdminSpanEdit.swift
//  MaTool
//
//  Created by 松下和也 on 2025/04/17.
//

import ComposableArchitecture
import Foundation
import Shared

@Reducer
struct AdminSpanEdit {
    enum Mode {
        case create
        case edit
    }
    
    @ObservableState
    struct State: Equatable{
        let mode: Mode
        @Presents var alert: Alert.State? = nil
        
        var period: Period
        
        init(_ period :Period){
            self.period = period
            mode = .edit
        }
        
        init(){
            let now = Date()
            period = .init(id: UUID().uuidString, date: .from(now), start: .from(now), end: .from(now))
            mode = .create
        }
    }
    @CasePathable
    enum Action: Equatable, BindableAction {
        case binding(BindingAction<State>)
        case doneTapped
        case cancelTapped
        case deleteTapped
        case alert(PresentationAction<Alert.Action>)
    }
    
    @Dependency(\.dismiss) var dismiss
    
    var body: some ReducerOf<AdminSpanEdit>{
        BindingReducer()
        Reduce{ state, action in
            switch action {
            case .binding:
                return .none
            case .doneTapped:
                return .none
            case .cancelTapped:
                return .run { _ in
                    await dismiss()
                }
            case .deleteTapped:
                if state.mode == .create {
                    return .none
                }
                state.alert = Alert.delete("このデータを削除してもよろしいですか。元の画面で保存を選択するとこのデータは削除され、操作を取り戻すことはできません。")
                return .none
            //Parent Use
            case .alert:
                state.alert = nil
                return .none
            }
        }
    }
}
