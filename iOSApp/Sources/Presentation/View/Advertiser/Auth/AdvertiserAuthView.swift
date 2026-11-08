import ComposableArchitecture
import SwiftUI

@available(iOS 17.0, *)
struct AdvertiserAuthScreen: View {
    @SwiftUI.Bindable var store: StoreOf<AdvertiserAuthFeature>

    var body: some View {
        WithPerceptionTracking {
            LoginContentView(
                id: $store.email,
                password: $store.password,
                contactURL: nil,
                errorMessage: store.errorMessage,
                isLoading: store.isLoading,
                identifierKind: .email,
                onResetPasswordTapped: { store.send(.resetPasswordTapped) },
                onSignInTapped: { store.send(.signInTapped) },
                createAccountTitle: "広告主アカウントを作成",
                onCreateAccountTapped: { store.send(.signUpTapped) }
            )
            .navigationTitle("広告主ログイン")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(
                item: $store.scope(state: \.destination?.signUp, action: \.destination.signUp)
            ) { signUpStore in
                AdvertiserSignUpScreen(store: signUpStore)
            }
            .navigationDestination(
                item: $store.scope(state: \.destination?.resetPassword, action: \.destination.resetPassword)
            ) { resetPasswordStore in
                ResetPasswordView(store: resetPasswordStore, usernameTitle: "メールアドレス")
            }
        }
    }
}
