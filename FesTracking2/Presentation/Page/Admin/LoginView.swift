//
//  LoginView.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/03/20.
//

import SwiftUI
import ComposableArchitecture

struct LoginView: View {
    let store: StoreOf<LoginFeature>
    
    init(store: StoreOf<LoginFeature>) {
        self.store = store
        print("LoginView")
    }

    var body: some View {
        WithViewStore(store, observe: { $0 }) { viewStore in
            VStack {
                Text("ログイン")
                    .font(.largeTitle)
                    .padding()
                
//                TextField("ユーザー名", text: viewStore.binding(
//                    get: \.username,
//                    send: .usernameChanged
//                ))
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()
                
//                SecureField("パスワード", text: viewStore.binding(
//                    get: \.password,
//                    send: .passwordChanged
//                ))
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()
                
                if let errorMessage = viewStore.errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .padding()
                }
                
                Button(action: {
                    viewStore.send(.signInButtonTapped)
                }) {
                    Text("ログイン")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .padding()
                Text(viewStore.errorMessage ?? "")
                    .font(.largeTitle)
                    .padding()
            }
            .padding()
        }
    }
    
}

//        NavigationView{
//            VStack {
//                if store.isSignIn {
//                    Text("ログイン中")
//                        .font(.title)
//                        .padding()
//                    Button(action: {
//                        store.send(AuthFeature.Action.loginButtonTapped)
//                    }) {
//                        Text("ログアウト")
//                            .frame(maxWidth: .infinity)
//                            .padding()
//                            .background(Color.red)
//                            .foregroundColor(.white)
//                            .cornerRadius(10)
//                    }
//                    .padding()
//                } else {
//                    Text("未ログイン")
//                        .font(.title)
//                        .padding()
//
////                    ifLetStore(store.scope(state: \.$loginPage, action: AuthFeature.Action.loginPage)) { loginStore in
////                        NavigationLink("ログイン") {
////                            LoginView(store: loginStore)
////                        }
////                    }
//
//                }
//            }
//            .padding()
//            .onAppear {
//                store.send(.checkUserState)
//            }
//        }
//        
