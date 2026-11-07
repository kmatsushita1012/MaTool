import ComposableArchitecture
import SwiftUI

struct AdvertiserAuthScreen: View {
    @SwiftUI.Bindable var store: StoreOf<AdvertiserAuthFeature>

    var body: some View {
        WithPerceptionTracking {
            AdvertiserAuthContentView(
                email: $store.email,
                password: $store.password,
                confirmationCode: $store.confirmationCode,
                isAwaitingConfirmation: store.isAwaitingConfirmation,
                isLoading: store.isLoading,
                errorMessage: store.errorMessage,
                onSignIn: { store.send(.signInTapped) },
                onSignUp: { store.send(.signUpTapped) },
                onConfirm: { store.send(.confirmationTapped) }
            )
        }
    }
}

struct AdvertiserAuthContentView: View {
    @Binding var email: String
    @Binding var password: String
    @Binding var confirmationCode: String
    let isAwaitingConfirmation: Bool
    let isLoading: Bool
    let errorMessage: String?
    let onSignIn: () -> Void
    let onSignUp: () -> Void
    let onConfirm: () -> Void

    var body: some View {
        Form {
            if isAwaitingConfirmation {
                Section("メール確認") {
                    TextField("確認コード", text: $confirmationCode)
                        .keyboardType(.numberPad)
                        .textContentType(.oneTimeCode)
                    Button("確認してログイン", action: onConfirm)
                        .disabled(isLoading || confirmationCode.isEmpty)
                        .loadingIndicator(isLoading: isLoading)
                }
            } else {
                Section("ログイン") {
                    TextField("メールアドレス", text: $email)
                        .keyboardType(.emailAddress)
                        .textContentType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    SecureField("パスワード", text: $password)
                        .textContentType(.password)
                    Button("ログイン", action: onSignIn)
                        .disabled(isLoading || email.isEmpty || password.isEmpty)
                        .loadingIndicator(isLoading: isLoading)
                }

                Section("はじめての方") {
                    Button("広告主アカウントを作成", action: onSignUp)
                        .disabled(isLoading || email.isEmpty || password.isEmpty)
                }
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle("広告主ログイン")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        AdvertiserAuthContentView(
            email: .constant(""),
            password: .constant(""),
            confirmationCode: .constant(""),
            isAwaitingConfirmation: false,
            isLoading: false,
            errorMessage: nil,
            onSignIn: {},
            onSignUp: {},
            onConfirm: {}
        )
    }
}
