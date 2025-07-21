//
//  ResetPasswordStoreView.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/07/17.
//

import ComposableArchitecture
import SwiftUI
import NavigationSwipeControl

struct ResetPasswordStoreView: View {
    
    @Bindable var store: StoreOf<ResetPassword>
    @FocusState private var focusedField: Field?
    
    enum Field {
        case username
        case newPassword1
        case newPassword2
        case code
    }
    
    var body: some View {
        VStack{
            TitleView(
                imageName: "SettingsBackground",
                titleText: "パスワード変更"
            ) {
                switch store.step{
                case .enterUsername:
                    store.send(.enterUsername(.dismissTapped))
                case .enterCode:
                    store.send(.enterCode(.dismissTapped))
                }
            }
            .ignoresSafeArea(edges: .top)
            Spacer()
            switch store.step{
            case .enterUsername:
                enterUsername
            case .enterCode:
                enterCode
            }
            Spacer()
        }
        .dismissible(backButton: false, edgeSwipe: false)
        .loadingOverlay(store.isLoading)
        .alert($store.scope(state: \.alert, action: \.alert))
    }
    
    @ViewBuilder
    var enterUsername: some View {
        VStack{
            Text("パスワードをリセットするには、登録済みのメールアドレスに送信された認証コードが必要です。")
                .foregroundStyle(.gray)
                .padding()
            VStack(alignment: .leading, spacing: 4) {
                Text("ID")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                TextField("", text: $store.username)
                    .textContentType(.none)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .focused($focusedField, equals: .username)
            }
            .padding()
            Button("認証コードを送信") {
                store.send(.enterUsername(.okTapped))
                focusedField = nil
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding()
        }
    }
    
    @ViewBuilder
    var enterCode: some View {
        VStack{
            SecureField("新しいパスワード", text: $store.newPassword1)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .focused($focusedField, equals: .newPassword1)
                .padding()
            SecureField("新しいパスワード（確認用）", text: $store.newPassword2)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .focused($focusedField, equals: .newPassword2)
                .padding()
            TextField("認証コード（6桁）", text: $store.code)
                .textContentType(.oneTimeCode)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .focused($focusedField, equals: .code)
                .padding()
            Button("パスワードを変更") {
                store.send(.enterCode(.okTapped))
                focusedField = nil
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding()
        }
    }
}
