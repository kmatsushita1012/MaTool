//
//  UpdateEmailView.swift
//  MaTool
//
//  Created by 松下和也 on 2025/07/17.
//

import ComposableArchitecture
import SwiftUI
import NavigationSwipeControl

@available(iOS 17.0, *)
struct UpdateEmailScreen: View {
    @SwiftUI.Bindable var store: StoreOf<UpdateEmailFeature>

    var body: some View {
        UpdateEmailContentView(
            step: store.step,
            email: $store.email,
            code: $store.code,
            isLoading: store.isLoading,
            onDismissTapped: {
                switch store.step {
                case .enterEmail:
                    store.send(.enterEmail(.dismissTapped))
                case .enterCode:
                    store.send(.enterCode(.dismissTapped))
                }
            },
            onEmailSubmitTapped: { store.send(.enterEmail(.okTapped)) },
            onCodeSubmitTapped: { store.send(.enterCode(.okTapped)) }
        )
        .preferredColorScheme(.light)
        .dismissible(backButton: false, edgeSwipe: false)
        .alert($store.scope(state: \.errorAlert, action: \.errorAlert))
        .alert($store.scope(state: \.completeAlert, action: \.completeAlert))
    }
}

@available(iOS 17.0, *)
typealias UpdateEmailView = UpdateEmailScreen

@available(iOS 17.0, *)
struct UpdateEmailContentView: View {
    let step: UpdateEmailFeature.State.Step
    @Binding var email: String
    @Binding var code: String
    let isLoading: Bool
    let onDismissTapped: () -> Void
    let onEmailSubmitTapped: () -> Void
    let onCodeSubmitTapped: () -> Void

    @FocusState private var focusedField: Field?

    private enum Field {
        case email
        case code
    }

    var body: some View {
        VStack{
            TitleView(
                text: "メールアドレス変更",
                image: "AdminBackground",
                font: .title
            ) {
                onDismissTapped()
            }
            .disabled(isLoading)
            .ignoresSafeArea(edges: .top)
            Spacer()
            switch step {
            case .enterEmail:
                enterEmail
            case .enterCode(let destination):
                UpdateEmailCodeContentView(
                    destination: destination,
                    code: $code,
                    isLoading: isLoading,
                    onSubmitTapped: onCodeSubmitTapped
                )
            }
            Spacer()
            Spacer()
        }
    }
    
    @ViewBuilder
    var enterEmail: some View {
        VStack{
            TextField("新しいメールアドレス", text: $email)
                .textContentType(.emailAddress)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .focused($focusedField, equals: .email)
                .padding()
            Button("変更") {
                onEmailSubmitTapped()
                focusedField = nil
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding()
            .loadingIndicator(isLoading: isLoading)
        }
        
    }
    
}

@available(iOS 17.0, *)
struct UpdateEmailCodeContentView: View {
    let destination: String
    @Binding var code: String
    let isLoading: Bool
    let onSubmitTapped: () -> Void

    @FocusState private var isCodeFieldFocused: Bool

    var body: some View {
        VStack{
            Text("入力されたメールアドレス　\(destination)　に6桁の確認コードを送信しました。次の画面で入力してください。")
                .foregroundStyle(.gray)
                .padding()
            TextField("認証コード（6桁）", text: $code)
                .textContentType(.oneTimeCode)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .focused($isCodeFieldFocused)
                .padding()
            Button("認証") {
                onSubmitTapped()
                isCodeFieldFocused = false
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding()
            .loadingIndicator(isLoading: isLoading)
        }
        .padding()
    }
}

#Preview {
    UpdateEmailContentView(
        step: .enterEmail,
        email: .constant(""),
        code: .constant(""),
        isLoading: false,
        onDismissTapped: {},
        onEmailSubmitTapped: {},
        onCodeSubmitTapped: {}
    )
}

#Preview("確認コード") {
    UpdateEmailCodeContentView(
        destination: "",
        code: .constant(""),
        isLoading: false,
        onSubmitTapped: {}
    )
}
