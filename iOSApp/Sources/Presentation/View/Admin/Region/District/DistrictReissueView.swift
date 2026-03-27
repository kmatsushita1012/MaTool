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
struct DistrictReissueView: View {
    @SwiftUI.Bindable var store: StoreOf<DistrictReissueFeature>

    var body: some View {
        List {
            Section {
                TextField("メールアドレスを入力", text: $store.email)
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
                store.send(.cancelTapped)
            }
            ToolbarSaveButton(title: "再発行") {
                store.send(.reissueTapped)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .dismissible(backButton: false)
        .loadingOverlay(store.isLoading)
        .alert($store.scope(state: \.alert, action: \.alert))
    }
}

