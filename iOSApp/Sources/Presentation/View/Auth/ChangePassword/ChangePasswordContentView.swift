//
//  ChangePasswordContentView.swift
//  MaTool
//

import SwiftUI

@available(iOS 17.0, *)
struct ChangePasswordContentView: View {
    @Binding var current: String
    @Binding var newPassword: String
    @Binding var confirmation: String
    let isLoading: Bool
    let onDismiss: () -> Void
    let onSubmit: () -> Void

    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case current
        case newPassword
        case confirmation
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
            VStack {
                TextField("現在のパスワード", text: $current)
                    .textContentType(.password)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .focused($focusedField, equals: .current)
                    .padding()
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
            .padding()
            Spacer()
        }
    }
}
