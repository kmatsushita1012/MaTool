//
//  LoginView.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/03/20.
//

import SwiftUI
import ComposableArchitecture

struct ConfirmSignInView: View {
    @Bindable var store: StoreOf<ConfirmSignInFeature>
    

    var body: some View {
        NavigationStack{
            VStack {
                Text("パスワード変更")
                    .font(.largeTitle)
                    .padding()
                SecureField("新しいパスワード", text: $store.newPassword)
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
        }
    }
    
}
