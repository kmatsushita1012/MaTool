import iOSShared
//
//  UpdateEmailContentView.swift
//  MaTool
//

import SwiftUI

@available(iOS 17.0, *)
public struct UpdateEmailContentView<Content: View>: View {
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
                text: "メールアドレス変更",
                image: "AdminBackground",
                font: .title,
                onDismiss: onDismiss
            )
            .ignoresSafeArea(edges: .top)
            Spacer()
            content()
            Spacer()
            Spacer()
        }
    }
}

@available(iOS 17.0, *)
public struct UpdateEmailEntryContentView: View {
    @Binding var email: String
    let isLoading: Bool
    let onSubmit: () -> Void

    @FocusState private var isEmailFocused: Bool

    public init(email: Binding<String>, isLoading: Bool, onSubmit: @escaping () -> Void) {
        self._email = email
        self.isLoading = isLoading
        self.onSubmit = onSubmit
    }

    public var body: some View {
        VStack {
            TextField("新しいメールアドレス", text: $email)
                .textContentType(.emailAddress)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .focused($isEmailFocused)
                .padding()
            Button("変更") {
                onSubmit()
                isEmailFocused = false
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
public struct UpdateEmailCodeContentView: View {
    @Binding var code: String
    let destination: String
    let isLoading: Bool
    let onSubmit: () -> Void

    @FocusState private var isCodeFocused: Bool

    public init(code: Binding<String>, destination: String, isLoading: Bool, onSubmit: @escaping () -> Void) {
        self._code = code
        self.destination = destination
        self.isLoading = isLoading
        self.onSubmit = onSubmit
    }

    public var body: some View {
        VStack {
            Text("入力されたメールアドレス　\(destination)　に6桁の確認コードを送信しました。次の画面で入力してください。")
                .foregroundStyle(.gray)
                .padding()
            TextField("認証コード（6桁）", text: $code)
                .textContentType(.oneTimeCode)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .focused($isCodeFocused)
                .padding()
            Button("認証") {
                onSubmit()
                isCodeFocused = false
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
        .padding()
    }
}
