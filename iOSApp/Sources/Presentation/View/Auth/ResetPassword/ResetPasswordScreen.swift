//
//  ResetPasswordScreen.swift
//  MaTool
//  Created by 松下和也 on 2025/07/17.
//

import ComposableArchitecture
import SwiftUI

@available(iOS 17.0, *)
struct ResetPasswordScreen: View {
    @SwiftUI.Bindable var store: StoreOf<ResetPasswordFeature>

    var body: some View {
        WithPerceptionTracking {
            ResetPasswordContentView(
                onDismiss: {
                    switch store.step {
                    case .enterUsername:
                        store.send(.enterUsername(.dismissTapped))
                    case .enterCode:
                        store.send(.enterCode(.dismissTapped))
                    }
                },
                content: {
                    switch store.step {
                    case .enterUsername:
                        ResetPasswordUsernameContentView(
                            username: $store.username,
                            isLoading: store.isLoading,
                            onSubmit: { store.send(.enterUsername(.okTapped)) }
                        )
                    case .enterCode:
                        ResetPasswordCodeContentView(
                            newPassword: $store.newPassword1,
                            confirmation: $store.newPassword2,
                            code: $store.code,
                            isLoading: store.isLoading,
                            onSubmit: { store.send(.enterCode(.okTapped)) }
                        )
                    }
                }
            )
            .preferredColorScheme(.light)
            .alert($store.scope(state: \.alert, action: \.alert))
        }
    }
}
