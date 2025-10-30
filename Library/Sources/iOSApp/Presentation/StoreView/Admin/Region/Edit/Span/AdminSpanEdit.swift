//
//  AdminSpanEdit.swift
//  MaTool
//
//  Created by 松下和也 on 2025/04/17.
//

import ComposableArchitecture
import Foundation

@Reducer
struct AdminSpanEdit {
    enum Mode {
        case create
        case edit
    }
    
    @ObservableState
    struct State: Equatable{
        let mode: Mode
        let id: String
        var date: Date
        var start: Date
        var end: Date
        @Presents var alert: Alert.State? = nil
        
        var span: Span {
            return Span(id: id, start: Date.combine(date: date, time: start), end: Date.combine(date: date, time: end))
        }
        
        init(_ span :Span){
            id = span.id
            date = span.start
            start = span.start
            end = span.end
            mode = .edit
        }
        
        init(){
            id = UUID().uuidString
            let now = Date()
            date = now
            start = Date.theDayAt(date: now, hour: 9, minute: 0, second: 0)
            end = Date.theDayAt(date: now, hour: 18, minute: 0, second: 0)
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
