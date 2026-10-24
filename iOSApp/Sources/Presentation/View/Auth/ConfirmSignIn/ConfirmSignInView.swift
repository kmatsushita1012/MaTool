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
        .loadingOverlay(store.isLoading)
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

    var body: some View {
        VStack {
            Text("パスワード変更")
                .font(.largeTitle)
                .padding()
            TextField("新しいパスワード", text: $password1)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()
            TextField("新しいパスワード（確認用）", text: $password2)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()
            Button(action: {
                onSubmitTapped()
            }) {
                Text("送信")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .padding()
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
