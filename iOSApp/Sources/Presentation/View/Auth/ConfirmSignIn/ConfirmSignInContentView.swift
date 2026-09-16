//
//  ConfirmSignInContentView.swift
//  MaTool
//

import SwiftUI

@available(iOS 17.0, *)
struct ConfirmSignInContentView: View {
    @Binding var password: String
    @Binding var confirmation: String
    let isLoading: Bool
    let onSubmit: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack {
            Text("パスワード変更")
                .font(.largeTitle)
                .padding()
            TextField("新しいパスワード", text: $password)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()
            TextField("新しいパスワード（確認用）", text: $confirmation)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()
            Button(action: onSubmit) {
                Text("送信")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .padding()
            .overlay {
                if isLoading {
                    ProgressView()
                }
            }
            .disabled(isLoading)
        }
        .padding()
        .toolbar {
            ToolbarBackButton(isDisabled: isLoading, action: onDismiss)
        }
    }
}
