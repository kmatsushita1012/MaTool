//
//  LoginView.swift
//  MaTool
//
//  Created by 松下和也 on 2025/03/20.
//

import SwiftUI
import ComposableArchitecture

@available(iOS 17.0, *)
struct LoginView: View {
    @SwiftUI.Bindable var store: StoreOf<LoginFeature>
    
    @FocusState private var focusedField: Field?
    
    enum Field {
        case identifier
        case password
    }
    
    var body: some View {
        VStack {
            Text("ログイン")
                .font(.largeTitle)
                .padding()
            TextField("ID", text: $store.id)
                .textContentType(.none)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .focused($focusedField, equals: .identifier)
                .padding()
                
            TextField("パスワード", text: $store.password)
                .textContentType(.password)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .focused($focusedField, equals: .password)
                .padding()
            
            if let errorMessage = store.errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .padding()
            }
            Button("ログイン") {
                store.send(.signInTapped)
                focusedField = nil
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding()
            .overlay {
                if store.isLoading {
                    ProgressView()
                }
            }
            .disabled(store.isLoading)
            Button("パスワードを忘れた場合") {
                store.send(.resetPasswordTapped)
                focusedField = nil
            }
            .buttonStyle(SecondaryButtonStyle())
            .padding()
        }
        .padding()
        .navigationDestination(item: $store.scope(state: \.destination, action: \.destination)) { destination in
            switch destination.case {
            case .confirmSignIn(let store):
                ConfirmSignInView(store: store)
            case .resetPassword(let store):
                ResetPasswordView(store: store)
            }
        }
    }
}
