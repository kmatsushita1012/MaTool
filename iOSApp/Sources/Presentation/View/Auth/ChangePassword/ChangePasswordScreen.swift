//
//  ChangePasswordScreen.swift
//  MaTool
//  Created by 松下和也 on 2025/07/17.
//

import SwiftUI
import ComposableArchitecture

@available(iOS 17.0, *)
struct ChangePasswordScreen: View {
    @SwiftUI.Bindable var store: StoreOf<ChangePasswordFeature>

    var body: some View {
        WithPerceptionTracking {
            ChangePasswordContentView(
                current: $store.current,
                newPassword: $store.new1,
                confirmation: $store.new2,
                isLoading: store.isLoading,
                onDismiss: { store.send(.dismissTapped) },
                onSubmit: { store.send(.okTapped) }
            )
            .preferredColorScheme(.light)
            .alert($store.scope(state: \.alert, action: \.alert))
        }
    }
}
