//
//  FeatureUtils.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/05/16.
//

import ComposableArchitecture

struct OkAlert {
    @CasePathable
    enum Action: Equatable {
        case okTapped
    }

    // typealias で AlertState を短縮
    typealias State = AlertState<Action>

    static func error(_ text: String, title: String = "エラー") -> State {
        State {
            TextState(title)
        } actions: {
            ButtonState(action: .okTapped) {
                TextState("確認")
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
                TextState("確認")
            }
        } message: {
            TextState(text)
        }
    }
}

