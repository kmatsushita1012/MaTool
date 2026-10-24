//
//  DistrictCreateView.swift
//  MaTool
//
//  Created by 松下和也 on 2025/05/12.
//

import SwiftUI
import ComposableArchitecture
import NavigationSwipeControl

@available(iOS 17.0, *)
struct DistrictCreateScreen: View {
    @SwiftUI.Bindable var store: StoreOf<DistrictCreateFeature>

    var body: some View {
        DistrictCreateContentView(
            name: $store.name,
            email: $store.email,
            onCancelTapped: { store.send(.cancelTapped) },
            onCreateTapped: { store.send(.createTapped) }
        )
        .dismissible(backButton: false)
        .loadingOverlay(store.isLoading)
        .alert($store.scope(state: \.alert, action: \.alert))
    }
}

@available(iOS 17.0, *)
typealias DistrictCreateView = DistrictCreateScreen

@available(iOS 17.0, *)
struct DistrictCreateContentView: View {
    @Binding var name: String
    @Binding var email: String
    let onCancelTapped: () -> Void
    let onCreateTapped: () -> Void

    var body: some View {
        List{
            Section(header: Text("町名")) {
                TextField("町名を入力", text: $name)
            }
            Section(header: Text("メールアドレス")) {
                TextField("メールアドレスを入力", text: $email)
                    .textContentType(.emailAddress)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
            }
        }
        .navigationTitle("新規作成")
        .toolbar {
            ToolbarCancelButton {
                onCancelTapped()
            }
            ToolbarSaveButton(title: "作成") {
                onCreateTapped()
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    DistrictCreateContentView(
        name: .constant(""),
        email: .constant(""),
        onCancelTapped: {},
        onCreateTapped: {}
    )
}
