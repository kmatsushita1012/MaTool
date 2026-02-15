//
//  FeatureUtils.swift
//  MaTool
//
//  Created by 松下和也 on 2025/05/16.
//

import ComposableArchitecture

extension AlertState {
    static func error(_ text: String, title: String = "エラー") -> AlertState<Alert.Action> {
        return Alert.error(text, title: title)
    }
    
    static func success(_ text: String, title: String = "完了") -> AlertState<Alert.Action> {
        return Alert.success(text, title: title)
    }
    
    static func notice(_ text: String, title: String = " お知らせ") -> AlertState<Alert.Action> {
        return Alert.notice(text, title: title)
    }
    
    static func delete(
        _ text: String = "このデータを削除してもよろしいですか？この操作は元に戻せません。",
        title: String = "確認"
    ) -> AlertState<Alert.Action> {
        return Alert.delete(text, title: title)
    }
}

@Reducer
struct Alert {
    @CasePathable
    enum Action: Equatable {
        case okTapped
    }

    // typealias で AlertState を短縮
    typealias State = AlertState<Action>
    
    var body: some ReducerOf<Alert> {
        Reduce { state, action in
            return Effect.none
        }
    }
    
    static func error(_ text: String, title: String = "エラー") -> State {
        State {
            TextState(title)
        } actions: {
            ButtonState(action: .okTapped) {
                TextState("OK")
            }
        } message: {
            TextState(text)
        }
    }
    
    static func success(_ text: String, title: String = "完了") -> State {
        State {
            TextState(title)
        } actions: {
            ButtonState(action: .okTapped) {
                TextState("OK")
            }
        } message: {
            TextState(text)
        }
    }
    
    static func notice(_ text: String, title: String = " お知らせ") -> State {
        State {
            TextState(title)
        } actions: {
            ButtonState(action: .okTapped) {
                TextState("OK")
            }
        } message: {
            TextState(text)
        }
    }
    
    static func delete(
        _ text: String = "このデータを削除してもよろしいですか？この操作は元に戻せません。",
        title: String = "確認"
    ) -> State {
        State {
            TextState(title)
        } actions: {
            ButtonState(role: .destructive, action: .okTapped) {
                TextState("削除")
            }
        } message: {
            TextState(text)
        }
    }
}

