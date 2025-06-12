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
    
    var body: some View {
        NavigationStack{
            VStack {
                Text("ログイン")
                    .font(.largeTitle)
                    .padding()
                TextField("ID（〇〇祭_×××）", text: $store.id)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding()
                SecureField("パスワード", text: $store.password)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding()
                
                if let errorMessage = store.errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .padding()
                }
                
                Button(action: {
                    store.send(.signInTapped)
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
        }
    }
}
