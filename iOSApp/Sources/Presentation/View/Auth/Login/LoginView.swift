//
//  LoginView.swift
//  MaTool
//
//  Created by 松下和也 on 2025/03/20.
//

import SwiftUI
import ComposableArchitecture
import NavigationSwipeControl
import UIKit

@available(iOS 17.0, *)
struct LoginScreen: View {
    @SwiftUI.Bindable var store: StoreOf<LoginFeature>
    @Dependency(\.values.contactURL) private var contactURLString

    var body: some View {
        LoginContentView(
            id: $store.id,
            password: $store.password,
            contactURL: URL(string: contactURLString),
            errorMessage: store.errorMessage,
            isLoading: store.isLoading,
            onResetPasswordTapped: { store.send(.resetPasswordTapped) },
            onSignInTapped: { store.send(.signInTapped) },
            onCreateAccountTapped: nil
        )
        .navigationDestination(item: $store.scope(state: \.destination?.confirmSignIn, action: \.destination.confirmSignIn)) { store in
            ConfirmSignInView(store: store)
        }
        .navigationDestination(item: $store.scope(state: \.destination?.resetPassword, action: \.destination.resetPassword)) { store in
            ResetPasswordView(store: store)
        }
    }
}

@available(iOS 17.0, *)
typealias LoginView = LoginScreen

@available(iOS 17.0, *)
struct LoginContentView: View {
    @Binding var id: String
    @Binding var password: String
    let contactURL: URL?
    let errorMessage: String?
    let isLoading: Bool
    var identifierKind: LoginIdentifierKind = .username
    let onResetPasswordTapped: () -> Void
    let onSignInTapped: () -> Void
    var createAccountTitle: LocalizedStringResource? = nil
    var onCreateAccountTapped: (() -> Void)? = nil

    @FocusState private var focusedField: Field?

    private enum Field {
        case identifier
        case password
    }

    var body: some View {
        VStack(spacing: 16) {
            Text("ログイン")
                .font(.largeTitle)
            TextField(identifierKind.title, text: $id)
                .textContentType(identifierKind.contentType)
                .keyboardType(identifierKind.keyboardType)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .modifier(AuthTextFieldModifier())
                .focused($focusedField, equals: .identifier)

            PasswordTextField(
                "パスワード",
                text: $password,
                focusedField: $focusedField,
                equals: .password
            )

            Button("ログイン") {
                onSignInTapped()
                focusedField = nil
            }
            .buttonStyle(PrimaryButtonStyle())
            .loadingIndicator(isLoading: isLoading)
            
            Button("パスワードを忘れた場合") {
                onResetPasswordTapped()
                focusedField = nil
            }
            .buttonStyle(.plain)
            .foregroundStyle(.tint)
            .disabled(isLoading)

            if let createAccountTitle, let onCreateAccountTapped {
                Button(createAccountTitle) {
                    onCreateAccountTapped()
                    focusedField = nil
                }
                .buttonStyle(SecondaryButtonStyle())
                .disabled(isLoading)
            }
            
            if let contactURL {
                Link(
                    "ログインできない場合: お問い合わせフォーム",
                    destination: contactURL
                )
            }

            Text(errorMessage ?? " ")
                .foregroundStyle(.red)
                .opacity(errorMessage == nil ? 0 : 1)
        }
        .padding()
    }
}

enum LoginIdentifierKind {
    case username
    case email

    var title: LocalizedStringKey {
        switch self {
        case .username: "ID"
        case .email: "メールアドレス"
        }
    }

    var contentType: UITextContentType {
        switch self {
        case .username: .username
        case .email: .emailAddress
        }
    }

    var keyboardType: UIKeyboardType {
        switch self {
        case .username: .default
        case .email: .default
        }
    }
}

#Preview {
    LoginContentView(
        id: .constant(""),
        password: .constant(""),
        contactURL: nil,
        errorMessage: nil,
        isLoading: false,
        onResetPasswordTapped: {},
        onSignInTapped: {},
        onCreateAccountTapped: nil
    )
}
