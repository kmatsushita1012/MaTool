//
//  ChangePasswordStoreView.swift
//  MaTool
//
//  Created by 松下和也 on 2025/07/17.
//

import SwiftUI
import ComposableArchitecture
import NavigationSwipeControl

@available(iOS 17.0, *)
struct ChangePasswordStoreView: View {
    
    @SwiftUI.Bindable var store: StoreOf<ChangePassword>
    @FocusState private var focusedField: Field?
    
    enum Field: Hashable {
        case current
        case new1
        case new2
    }
    
    var body: some View {
        VStack {
            TitleView(
                text: "パスワード変更",
                image: "AdminBackground"
            ) {
                store.send(.dismissTapped)
            }
            .ignoresSafeArea(edges: .top)
            Spacer()
            VStack {
                SecureField("現在のパスワード", text: $store.current)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .focused($focusedField, equals: .current)
                    .padding()
                SecureField("新しいパスワード", text: $store.new1)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .focused($focusedField, equals: .new1)
                    .padding()
                SecureField("新しいパスワード（確認用）", text: $store.new2)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .focused($focusedField, equals: .new2)
                    .padding()
                Button("パスワードを変更") {
                    store.send(.okTapped)
                    focusedField = nil
                }
                .buttonStyle(PrimaryButtonStyle())
                .padding()
            }
            .padding()
            Spacer()
        }
        .dismissible(backButton: false, edgeSwipe: false)
        .loadingOverlay(store.isLoading)
        .alert($store.scope(state: \.alert, action: \.alert))
    }
}


