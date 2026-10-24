//
//  DistrictReissueView.swift
//  MaTool
//
//  Created by Codex on 2026/03/28.
//

import SwiftUI
import ComposableArchitecture
import NavigationSwipeControl

@available(iOS 17.0, *)
struct DistrictReissueScreen: View {
    @SwiftUI.Bindable var store: StoreOf<DistrictReissueFeature>

    var body: some View {
        DistrictReissueContentView(
            email: $store.email,
            onCancelTapped: { store.send(.cancelTapped) },
            onReissueTapped: { store.send(.reissueTapped) }
        )
        .dismissible(backButton: false)
        .loadingOverlay(store.isLoading)
        .alert($store.scope(state: \.alert, action: \.alert))
    }
}

@available(iOS 17.0, *)
typealias DistrictReissueView = DistrictReissueScreen

@available(iOS 17.0, *)
struct DistrictReissueContentView: View {
    @Binding var email: String
    let onCancelTapped: () -> Void
    let onReissueTapped: () -> Void

    var body: some View {
        List {
            Section {
                TextField("メールアドレスを入力", text: $email)
                    .textContentType(.emailAddress)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
            } header: {
                Text("新しいメールアドレス")
            } footer: {
                Text("再発行すると既存アカウントは無効になり、ここで入力したメールアドレスで再登録が必要になります。")
            }
        }
        .navigationTitle("アカウント再発行")
        .toolbar {
            ToolbarCancelButton {
                onCancelTapped()
            }
            ToolbarSaveButton(title: "再発行") {
                onReissueTapped()
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    DistrictReissueContentView(
        email: .constant(""),
        onCancelTapped: {},
        onReissueTapped: {}
    )
}

