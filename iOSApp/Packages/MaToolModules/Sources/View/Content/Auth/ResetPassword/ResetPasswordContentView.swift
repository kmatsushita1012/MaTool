import iOSShared
//
//  ResetPasswordContentView.swift
//  MaTool
//

import SwiftUI

@available(iOS 17.0, *)
public struct ResetPasswordContentView<Content: View>: View {
    let onDismiss: () -> Void
    private let content: () -> Content

    public init(
        onDismiss: @escaping () -> Void,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.onDismiss = onDismiss
        self.content = content
    }

    public var body: some View {
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
public struct ResetPasswordUsernameContentView: View {
    @Binding var username: String
    let isLoading: Bool
    let onSubmit: () -> Void

    @FocusState private var isUsernameFocused: Bool

    public init(username: Binding<String>, isLoading: Bool, onSubmit: @escaping () -> Void) {
        self._username = username
        self.isLoading = isLoading
        self.onSubmit = onSubmit
    }

    public var body: some View {
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
public struct ResetPasswordCodeContentView: View {
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

    public init(
        newPassword: Binding<String>,
        confirmation: Binding<String>,
        code: Binding<String>,
        isLoading: Bool,
        onSubmit: @escaping () -> Void
    ) {
        self._newPassword = newPassword
        self._confirmation = confirmation
        self._code = code
        self.isLoading = isLoading
        self.onSubmit = onSubmit
    }

    public var body: some View {
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
