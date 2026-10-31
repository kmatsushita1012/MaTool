//
//  ResetPasswordView.swift
//  MaTool
//
//  Created by 松下和也 on 2025/07/17.
//

import ComposableArchitecture
import SwiftUI
import NavigationSwipeControl

@available(iOS 17.0, *)
struct ResetPasswordScreen: View {
    @SwiftUI.Bindable var store: StoreOf<ResetPasswordFeature>

    var body: some View {
        ResetPasswordContentView(
            step: store.step,
            username: $store.username,
            newPassword1: $store.newPassword1,
            newPassword2: $store.newPassword2,
            code: $store.code,
            isLoading: store.isLoading,
            onDismissTapped: {
                switch store.step {
                case .enterUsername:
                    store.send(.enterUsername(.dismissTapped))
                case .enterCode:
                    store.send(.enterCode(.dismissTapped))
                }
            },
            onUsernameSubmitTapped: { store.send(.enterUsername(.okTapped)) },
            onCodeSubmitTapped: { store.send(.enterCode(.okTapped)) }
        )
        .dismissible(backButton: false, edgeSwipe: false)
        .alert($store.scope(state: \.alert, action: \.alert))
    }
}

@available(iOS 17.0, *)
typealias ResetPasswordView = ResetPasswordScreen

@available(iOS 17.0, *)
struct ResetPasswordContentView: View {
    let step: ResetPasswordFeature.State.Step
    @Binding var username: String
    @Binding var newPassword1: String
    @Binding var newPassword2: String
    @Binding var code: String
    let isLoading: Bool
    let onDismissTapped: () -> Void
    let onUsernameSubmitTapped: () -> Void
    let onCodeSubmitTapped: () -> Void

    @FocusState private var focusedField: Field?

    private enum Field {
        case username
        case newPassword1
        case newPassword2
        case code
    }

    var body: some View {
        VStack{
            TitleView(
                text: "パスワード変更",
                image: "AdminBackground"
            ) {
                onDismissTapped()
            }
            .disabled(isLoading)
            .ignoresSafeArea(edges: .top)
            Spacer()
            switch step {
            case .enterUsername:
                enterUsername
            case .enterCode:
                enterCode
            }
            Spacer()
        }
        .preferredColorScheme(.light)
    }
    
    @ViewBuilder
    var enterUsername: some View {
        VStack{
            Text("パスワードをリセットするには、登録済みのメールアドレスに送信された認証コードが必要です。")
                .foregroundStyle(.gray)
                .padding()
            VStack(alignment: .leading, spacing: 4) {
                Text("ID（ユーザー名）")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                TextField("", text: $username)
                    .textContentType(.none)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .focused($focusedField, equals: .username)
            }
            .padding()
            Button("認証コードを送信") {
                onUsernameSubmitTapped()
                focusedField = nil
            }
            .buttonStyle(PrimaryButtonStyle())
            .loadingIndicator(isLoading: isLoading)
            .padding()
        }
    }
    
    @ViewBuilder
    var enterCode: some View {
        VStack{
            TextField("新しいパスワード", text: $newPassword1)
                .textContentType(.password)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .focused($focusedField, equals: .newPassword1)
                .padding()
            TextField("新しいパスワード（確認用）", text: $newPassword2)
                .textContentType(.password)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .focused($focusedField, equals: .newPassword2)
                .padding()
            TextField("認証コード（6桁）", text: $code)
                .textContentType(.oneTimeCode)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .focused($focusedField, equals: .code)
                .padding()
            Button("パスワードを変更") {
                onCodeSubmitTapped()
                focusedField = nil
            }
            .buttonStyle(PrimaryButtonStyle())
            .loadingIndicator(isLoading: isLoading)
            .padding()
        }
    }
}

#Preview {
    ResetPasswordContentView(
        step: .enterUsername,
        username: .constant(""),
        newPassword1: .constant(""),
        newPassword2: .constant(""),
        code: .constant(""),
        isLoading: false,
        onDismissTapped: {},
        onUsernameSubmitTapped: {},
        onCodeSubmitTapped: {}
    )
}
