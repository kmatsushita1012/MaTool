//
//  ChangePasswordView.swift
//  MaTool
//
//  Created by 松下和也 on 2025/07/17.
//

import SwiftUI
import ComposableArchitecture
import NavigationSwipeControl

@available(iOS 17.0, *)
struct ChangePasswordScreen: View {
    @SwiftUI.Bindable var store: StoreOf<ChangePasswordFeature>

    var body: some View {
        ChangePasswordContentView(
            current: $store.current,
            new1: $store.new1,
            new2: $store.new2,
            isLoading: store.isLoading,
            onSubmitTapped: { store.send(.okTapped) },
            onDismissTapped: { store.send(.dismissTapped) }
        )
        .dismissible(backButton: false, edgeSwipe: false)
        .alert($store.scope(state: \.alert, action: \.alert))
    }
}

@available(iOS 17.0, *)
typealias ChangePasswordView = ChangePasswordScreen

@available(iOS 17.0, *)
struct ChangePasswordContentView: View {
    @Binding var current: String
    @Binding var new1: String
    @Binding var new2: String
    let isLoading: Bool
    let onSubmitTapped: () -> Void
    let onDismissTapped: () -> Void

    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case current
        case new1
        case new2
    }

    var body: some View {
        VStack(spacing: 16) {
            Text("パスワード変更")
                .font(.largeTitle)
            TextField("現在のパスワード", text: $current)
                .textContentType(.password)
                .keyboardType(.asciiCapable)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .modifier(AuthTextFieldModifier())
                .focused($focusedField, equals: .current)
            TextField("新しいパスワード", text: $new1)
                .textContentType(.password)
                .keyboardType(.asciiCapable)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .modifier(AuthTextFieldModifier())
                .focused($focusedField, equals: .new1)
            TextField("新しいパスワード（確認用）", text: $new2)
                .textContentType(.password)
                .keyboardType(.asciiCapable)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .modifier(AuthTextFieldModifier())
                .focused($focusedField, equals: .new2)
            Button("パスワードを変更") {
                onSubmitTapped()
                focusedField = nil
            }
            .buttonStyle(PrimaryButtonStyle())
            .loadingIndicator(isLoading: isLoading)
        }
        .padding()
        .toolbar {
            ToolbarBackButton(isDisabled: isLoading) {
                onDismissTapped()
            }
        }
    }
}

#Preview {
    ChangePasswordContentView(
        current: .constant(""),
        new1: .constant(""),
        new2: .constant(""),
        isLoading: false,
        onSubmitTapped: {},
        onDismissTapped: {}
    )
}
