//
//  LoginView.swift
//  MaTool
//
//  Created by 松下和也 on 2025/03/20.
//

import SwiftUI
import ComposableArchitecture
import NavigationSwipeControl

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
            onSignInTapped: { store.send(.signInTapped) },
            onResetPasswordTapped: { store.send(.resetPasswordTapped) }
        )
        .navigationDestination(item: $store.scope(state: \.destination?.confirmSignIn, action: \.destination.confirmSignIn)) { store in
            ConfirmSignInView(store: store)
        }
        .navigationDestination(item: $store.scope(state: \.destination?.resetPassword, action: \.destination.resetPassword)) { store in
            ResetPasswordView(store: store)
        }
        .loadingOverlay(store.isLoading)
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
    let onSignInTapped: () -> Void
    let onResetPasswordTapped: () -> Void

    @FocusState private var focusedField: Field?

    private enum Field {
        case identifier
        case password
    }

    var body: some View {
        VStack(spacing: 16) {
            Text("ログイン")
                .font(.largeTitle)
            TextField("ID", text: $id)
                .padding()
                .textContentType(.username)
                .textFieldStyle(.plain)
                .background(.regularMaterial, in: .capsule)
                .overlay {
                        Capsule()
                            .stroke(.secondary, lineWidth: 1)
                    }
                .focused($focusedField, equals: .identifier)
                
            TextField("パスワード", text: $password)
                .padding()
                .textContentType(.password)
                .textFieldStyle(.plain)
                .background(.regularMaterial, in: .capsule)
                .overlay {
                        Capsule()
                            .stroke(.secondary, lineWidth: 1)
                    }
                .focused($focusedField, equals: .password)
            
            Button("ログイン") {
                onSignInTapped()
                focusedField = nil
            }
            .buttonStyle(PrimaryButtonStyle())
            
            Button("パスワードを忘れた場合") {
                onResetPasswordTapped()
                focusedField = nil
            }
            .buttonStyle(SecondaryButtonStyle())
            
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

#Preview {
    LoginContentView(
        id: .constant(""),
        password: .constant(""),
        contactURL: nil,
        errorMessage: nil,
        onSignInTapped: {},
        onResetPasswordTapped: {}
    )
}
