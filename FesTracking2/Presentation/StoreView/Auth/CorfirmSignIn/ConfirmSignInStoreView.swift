//
//  LoginStoreView.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/03/20.
//

import SwiftUI
import ComposableArchitecture
import NavigationSwipeControl

struct ConfirmSignInStoreView: View {
    @Bindable var store: StoreOf<ConfirmSignIn>
    
    var body: some View {
        VStack {
            Text("パスワード変更")
                .font(.largeTitle)
                .padding()
            SecureField("新しいパスワード", text: $store.password1)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()
            SecureField("新しいパスワード（確認用）", text: $store.password2)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()
            Button(action: {
                store.send(.submitTapped)
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
            ToolbarItem(placement: .topBarLeading) {
                Button(action: {
                    store.send(.dismissTapped)
                }) {
                    Image(systemName: "house")
                        .foregroundColor(.black)
                }
                .padding(.horizontal, 8)
            }
        }
        .dismissible(backButton: false)
        .alert($store.scope(state: \.alert, action: \.alert))
        .loadingOverlay(store.isLoading)
    }
}
