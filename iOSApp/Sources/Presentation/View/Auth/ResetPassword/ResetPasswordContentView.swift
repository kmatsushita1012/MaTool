//
//  ResetPasswordContentView.swift
//  MaTool
//

import SwiftUI

@available(iOS 17.0, *)
struct ResetPasswordContentView<Content: View>: View {
    let onDismiss: () -> Void
    private let content: () -> Content

    init(
        onDismiss: @escaping () -> Void,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.onDismiss = onDismiss
        self.content = content
    }

    var body: some View {
        VStack {
            TitleView(
                text: "パスワード変更",
                image: "AdminBackground",
                onDismiss: onDismiss
            )
            .ignoresSafeArea(edges: .top)
            Spacer()
            content()
            Spacer()
        }
    }
}

@available(iOS 17.0, *)
struct ResetPasswordUsernameContentView: View {
    @Binding var username: String
    let isLoading: Bool
    let onSubmit: () -> Void

    @FocusState private var isUsernameFocused: Bool

    var body: some View {
        VStack {
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
                    .focused($isUsernameFocused)
            }
            .padding()
            Button("認証コードを送信") {
                onSubmit()
                isUsernameFocused = false
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding()
            .overlay {
                if isLoading {
                    ProgressView()
                }
            }
            .disabled(isLoading)
        }
    }
}

@available(iOS 17.0, *)
struct ResetPasswordCodeContentView: View {
    @Binding var newPassword: String
    @Binding var confirmation: String
    @Binding var code: String
    let isLoading: Bool
    let onSubmit: () -> Void

    @FocusState private var focusedField: Field?

    private enum Field {
        case newPassword
        case confirmation
        case code
    }

    var body: some View {
        VStack {
            TextField("新しいパスワード", text: $newPassword)
                .textContentType(.password)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .focused($focusedField, equals: .newPassword)
                .padding()
            TextField("新しいパスワード（確認用）", text: $confirmation)
                .textContentType(.password)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .focused($focusedField, equals: .confirmation)
                .padding()
            TextField("認証コード（6桁）", text: $code)
                .textContentType(.oneTimeCode)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .focused($focusedField, equals: .code)
                .padding()
            Button("パスワードを変更") {
                onSubmit()
                focusedField = nil
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding()
            .overlay {
                if isLoading {
                    ProgressView()
                }
            }
            .disabled(isLoading)
        }
    }
}
