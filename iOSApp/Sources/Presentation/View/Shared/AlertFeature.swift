//
//  AlertFeature.swift
//  MaTool
//
//  Created by 松下和也 on 2025/05/16.
//

import ComposableArchitecture

extension AlertState {
    static func error(_ text: String, title: String = "エラー") -> AlertState<AlertFeature.Action> {
        return AlertFeature.error(text, title: title)
    }

    static func error(_ error: AppError, title: String = "エラー") -> AlertState<AlertFeature.Action> {
        AlertFeature.error(error.message, title: title)
    }
    
    static func success(_ text: String, title: String = "完了") -> AlertState<AlertFeature.Action> {
        return AlertFeature.success(text, title: title)
    }
    
    static func notice(_ text: String, title: String = " お知らせ") -> AlertState<AlertFeature.Action> {
        return AlertFeature.notice(text, title: title)
    }
    
    static func delete(
        _ text: String = "このデータを削除してもよろしいですか？この操作は元に戻せません。",
        title: String = "確認"
    ) -> AlertState<AlertFeature.Action> {
        return AlertFeature.delete(text, title: title)
    }
}

@Reducer
struct AlertFeature {
    @CasePathable
    enum Action: Equatable {
        case okTapped
        case confirmTapped
        case cancelTapped
    }

    // typealias で AlertState を短縮
    typealias State = AlertState<Action>
    
    var body: some ReducerOf<AlertFeature> {
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

    static func participationChangeConfirmation() -> State {
        State {
            TextState("参加設定を変更")
        } actions: {
            ButtonState(role: .cancel, action: .cancelTapped) {
                TextState("キャンセル")
            }
            ButtonState(action: .confirmTapped) {
                TextState("OK")
            }
        } message: {
            TextState("参加設定を変更すると、管理者アカウントからサインアウトします。続けますか？")
        }
    }
}
