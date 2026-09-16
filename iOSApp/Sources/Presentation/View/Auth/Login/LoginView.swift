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
struct LoginView: View {
    @SwiftUI.Bindable var store: StoreOf<LoginFeature>
    @Dependency(\.values.contactURL) private var contactURLString
    
    @FocusState private var focusedField: Field?
    
    enum Field {
        case identifier
        case password
    }
    
    var body: some View {
        VStack(spacing: 16) {
            Text("ログイン")
                .font(.largeTitle)
            TextField("ID", text: $store.id)
                .padding()
                .textContentType(.username)
                .textFieldStyle(.plain)
                .background(.regularMaterial, in: .capsule)
                .overlay {
                        Capsule()
                            .stroke(.secondary, lineWidth: 1)
                    }
                .focused($focusedField, equals: .identifier)
                
            TextField("パスワード", text: $store.password)
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
                store.send(.signInTapped)
                focusedField = nil
            }
            .buttonStyle(PrimaryButtonStyle())
            
            Button("パスワードを忘れた場合") {
                store.send(.resetPasswordTapped)
                focusedField = nil
            }
            .buttonStyle(SecondaryButtonStyle())
            
            Link(
                "ログインできない場合: お問い合わせフォーム",
                destination: URL(string: contactURLString)!
            )

            Text(store.errorMessage ?? " ")
                .foregroundStyle(.red)
                .opacity(store.errorMessage == nil ? 0 : 1)
        }
        .padding()
        .navigationDestination(item: $store.scope(state: \.destination?.confirmSignIn, action: \.destination.confirmSignIn)){ store in
            ConfirmSignInView(store:store)
        }
        .navigationDestination(item: $store.scope(state: \.destination?.resetPassword, action: \.destination.resetPassword)){ store in
            ResetPasswordView(store:store)
        }
        .loadingOverlay(store.isLoading)
    }
}
