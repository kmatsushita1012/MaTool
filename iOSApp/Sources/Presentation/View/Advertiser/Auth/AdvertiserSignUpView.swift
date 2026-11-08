import ComposableArchitecture
import SwiftUI

@available(iOS 17.0, *)
struct AdvertiserSignUpScreen: View {
    @SwiftUI.Bindable var store: StoreOf<AdvertiserSignUpFeature>

    var body: some View {
        WithPerceptionTracking {
            AdvertiserSignUpContentView(
                email: $store.email,
                password: $store.password,
                confirmationCode: $store.confirmationCode,
                isAwaitingConfirmation: store.isAwaitingConfirmation,
                isLoading: store.isLoading,
                errorMessage: store.errorMessage,
                onSignUpTapped: { store.send(.signUpTapped) },
                onConfirmationTapped: { store.send(.confirmationTapped) }
            )
        }
    }
}

@available(iOS 17.0, *)
struct AdvertiserSignUpContentView: View {
    @Binding var email: String
    @Binding var password: String
    @Binding var confirmationCode: String
    let isAwaitingConfirmation: Bool
    let isLoading: Bool
    let errorMessage: String?
    let onSignUpTapped: () -> Void
    let onConfirmationTapped: () -> Void

    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case email
        case password
        case confirmationCode
    }

    var body: some View {
        VStack(spacing: 16) {
            Text(isAwaitingConfirmation ? "メール確認" : "アカウントを作成")
                .font(.largeTitle)

            if isAwaitingConfirmation {
                TextField("確認コード", text: $confirmationCode)
                    .keyboardType(.numberPad)
                    .textContentType(.oneTimeCode)
                    .modifier(AuthTextFieldModifier())
                    .focused($focusedField, equals: .confirmationCode)

                Button("確認してログイン") {
                    onConfirmationTapped()
                    focusedField = nil
                }
                .buttonStyle(PrimaryButtonStyle())
                .loadingIndicator(isLoading: isLoading)
                .disabled(isLoading || confirmationCode.isEmpty)
            } else {
                TextField("メールアドレス", text: $email)
                    .keyboardType(.emailAddress)
                    .textContentType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .modifier(AuthTextFieldModifier())
                    .focused($focusedField, equals: .email)

                PasswordTextField(
                    "パスワード",
                    text: $password,
                    focusedField: $focusedField,
                    equals: .password
                )

                Button("アカウントを作成") {
                    onSignUpTapped()
                    focusedField = nil
                }
                .buttonStyle(PrimaryButtonStyle())
                .loadingIndicator(isLoading: isLoading)
                .disabled(isLoading || email.isEmpty || password.isEmpty)
            }

            Text(errorMessage ?? " ")
                .foregroundStyle(.red)
                .opacity(errorMessage == nil ? 0 : 1)
        }
        .padding()
        .navigationTitle("広告主アカウント作成")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        AdvertiserSignUpContentView(
            email: .constant(""),
            password: .constant(""),
            confirmationCode: .constant(""),
            isAwaitingConfirmation: false,
            isLoading: false,
            errorMessage: nil,
            onSignUpTapped: {},
            onConfirmationTapped: {}
        )
    }
}
