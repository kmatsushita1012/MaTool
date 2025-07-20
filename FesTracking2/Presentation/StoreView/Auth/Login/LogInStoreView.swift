//
//  LoginStoreView.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/03/20.
//

import SwiftUI
import ComposableArchitecture

struct LoginStoreView: View {
    @Bindable var store: StoreOf<Login>
    
    @FocusState private var focusedField: Field?
    
    enum Field {
        case identifier
        case password
    }
    
    var body: some View {
        NavigationView{
            VStack {
                Text("ログイン")
                    .font(.largeTitle)
                    .padding()
                TextField("ID", text: $store.id)
                    .textContentType(.none)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .focused($focusedField, equals: .identifier)
                    .padding()
                    
                SecureField("パスワード", text: $store.password)
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
                Button("パスワードを忘れた場合") {
                    store.send(.resetPasswordTapped)
                    focusedField = nil
                }
                .buttonStyle(SecondaryButtonStyle())
                .padding()
            }
            .padding()
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: {
                        store.send(.homeTapped)
                    }) {
                        Image(systemName: "house")
                            .foregroundColor(.black)
                    }
                    .padding(.horizontal, 8)
                }
            }
            .navigationDestination(item: $store.scope(state: \.destination?.confirmSignIn, action: \.destination.confirmSignIn)){ store in
                ConfirmSignInStoreView(store:store)
                    .interactiveDismissDisabled(true)
                    .navigationBarBackButtonHidden(true)
            }
            .navigationDestination(item: $store.scope(state: \.destination?.resetPassword, action: \.destination.resetPassword)){ store in
                ResetPasswordStoreView(store:store)
                    .navigationBarBackButtonHidden(true)
            }
            .loadingOverlay(store.isLoading)
        }
    }
}
