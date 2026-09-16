//
//  LoginScreen.swift
//  MaTool
//  Created by 松下和也 on 2025/03/20.
//

import SwiftUI
import ComposableArchitecture

@available(iOS 17.0, *)
struct LoginScreen: View {
    @SwiftUI.Bindable var store: StoreOf<LoginFeature>

    var body: some View {
        WithPerceptionTracking {
            LoginContentView(
                id: $store.id,
                password: $store.password,
                errorMessage: store.errorMessage,
                isLoading: store.isLoading,
                onSignIn: { store.send(.signInTapped) },
                onResetPassword: { store.send(.resetPasswordTapped) }
            )
            .navigationDestination(item: $store.scope(state: \.destination, action: \.destination)) { destination in
                switch destination.case {
                case .confirmSignIn(let store):
                    ConfirmSignInScreen(store: store)
                case .resetPassword(let store):
                    ResetPasswordScreen(store: store)
                }
            }
        }
    }
}
