import iOSShared
import Application
import View
//
//  ConfirmSignInScreen.swift
//  MaTool
//  Created by 松下和也 on 2025/03/20.
//

import SwiftUI
import ComposableArchitecture

@available(iOS 17.0, *)
struct ConfirmSignInScreen: View {
    @SwiftUI.Bindable var store: StoreOf<ConfirmSignInFeature>

    var body: some View {
        WithPerceptionTracking {
            ConfirmSignInContentView(
                password: $store.password1,
                confirmation: $store.password2,
                isLoading: store.isLoading,
                onSubmit: { store.send(.submitTapped) },
                onDismiss: { store.send(.dismissTapped) }
            )
            .alert($store.scope(state: \.alert, action: \.alert))
        }
    }
}
