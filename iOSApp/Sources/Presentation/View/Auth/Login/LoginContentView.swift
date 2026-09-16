//
//  LoginContentView.swift
//  MaTool
//

import SwiftUI

@available(iOS 17.0, *)
struct LoginContentView: View {
    @Binding var id: String
    @Binding var password: String
    let errorMessage: String?
    let isLoading: Bool
    let onSignIn: () -> Void
    let onResetPassword: () -> Void

    @FocusState private var focusedField: Field?

    private enum Field {
        case identifier
        case password
    }

    var body: some View {
        VStack {
            Text("ログイン")
                .font(.largeTitle)
                .padding()
            TextField("ID", text: $id)
                .textContentType(.none)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .focused($focusedField, equals: .identifier)
                .padding()

            TextField("パスワード", text: $password)
                .textContentType(.password)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .focused($focusedField, equals: .password)
                .padding()

            if let errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .padding()
            }
            Button("ログイン") {
                onSignIn()
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
            Button("パスワードを忘れた場合") {
                onResetPassword()
                focusedField = nil
            }
            .buttonStyle(SecondaryButtonStyle())
            .padding()
        }
        .padding()
    }
}
