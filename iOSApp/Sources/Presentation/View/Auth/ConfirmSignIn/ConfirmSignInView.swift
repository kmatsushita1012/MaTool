//
//  ConfirmSignInView.swift
//  MaTool
//
//  Created by 松下和也 on 2025/03/20.
//

import SwiftUI
import ComposableArchitecture
import NavigationSwipeControl

@available(iOS 17.0, *)
struct ConfirmSignInScreen: View {
    @SwiftUI.Bindable var store: StoreOf<ConfirmSignInFeature>

    var body: some View {
        ConfirmSignInContentView(
            password1: $store.password1,
            password2: $store.password2,
            isLoading: store.isLoading,
            onSubmitTapped: { store.send(.submitTapped) },
            onDismissTapped: { store.send(.dismissTapped) }
        )
        .dismissible(backButton: false)
        .alert($store.scope(state: \.alert, action: \.alert))
    }
}

@available(iOS 17.0, *)
typealias ConfirmSignInView = ConfirmSignInScreen

@available(iOS 17.0, *)
struct ConfirmSignInContentView: View {
    @Binding var password1: String
    @Binding var password2: String
    let isLoading: Bool
    let onSubmitTapped: () -> Void
    let onDismissTapped: () -> Void

    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case password1
        case password2
    }

    var body: some View {
        VStack(spacing: 16) {
            Text("パスワード変更")
                .font(.largeTitle)
            PasswordTextField(
                "新しいパスワード",
                text: $password1,
                focusedField: $focusedField,
                equals: .password1
            )
            PasswordTextField(
                "新しいパスワード（確認用）",
                text: $password2,
                focusedField: $focusedField,
                equals: .password2
            )
            Button("送信") {
                onSubmitTapped()
                focusedField = nil
            }
            .buttonStyle(PrimaryButtonStyle())
            .loadingIndicator(isLoading: isLoading)
        }
        .padding()
        .toolbar {
            ToolbarBackButton(isDisabled: isLoading) {
                onDismissTapped()
            }
        }
    }
}

#Preview {
    ConfirmSignInContentView(
        password1: .constant(""),
        password2: .constant(""),
        isLoading: false,
        onSubmitTapped: {},
        onDismissTapped: {}
    )
}
