//
//  LoginView.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/03/20.
//

import SwiftUI
import ComposableArchitecture

struct LoginView: View {
    @Bindable var store: StoreOf<LoginFeature>
    

    var body: some View {
        VStack {
            Text("ログイン")
                .font(.largeTitle)
                .padding()
            TextField("ユーザー名", text: $store.username)
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
                store.send(.signInButtonTapped)
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
        
    }
    
}
