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
                
                Button(action: {
                    store.send(.signInTapped)
                    focusedField = nil
                }) {
                    Text("ログイン")
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
            .fullScreenCover(item: $store.scope(state: \.confirmSignIn, action: \.confirmSignIn)){ store in
                ConfirmSignInStoreView(store:store)
            }
            .loadingOverlay(store.isLoading)
        }
    }
}
