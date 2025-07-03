//
//  AdminPerformanceEdit.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/04/17.
//

import SwiftUI
import ComposableArchitecture

@Reducer
struct AdminPerformanceEdit{
    enum Mode {
        case edit
        case create
    }
    @ObservableState
    struct State: Equatable{
        let mode: Mode
        var item: Performance
        @Presents var alert: Alert.State? = nil
        init(item: Performance){
            self.item = item
            mode = .edit
        }
        init(){
            item = Performance(id: UUID().uuidString)
            mode = .create
        }
    }
    
    enum Action: BindableAction, Equatable{
        case binding(BindingAction<State>)
        case doneTapped
        case cancelTapped
        case deleteTapped
        case alert(PresentationAction<Alert.Action>)
    }
    
    var body: some ReducerOf<AdminPerformanceEdit>{
        BindingReducer()
        Reduce{ state, action in
            switch action {
            case .binding:
                return .none
            case .doneTapped:
                return .none
            case .cancelTapped:
                return .none
            case .deleteTapped:
                if state.mode == .create {
                    return .none
                }
                state.alert = Alert.delete("このデータを削除してもよろしいですか。元の画面で保存を押すと削除され、操作を取り戻すことはできません。")
                return .none
            //Parent Use
            case .alert(.presented(.okTapped)):
                state.alert = nil
                return .none
            case .alert:
                state.alert = nil
                return .none
            }
        }
    }
}
