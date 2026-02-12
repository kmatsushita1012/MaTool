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
struct DistrictCreateView: View {
    
    @SwiftUI.Bindable var store: StoreOf<DistrictCreateFeature>
    
    var body: some View {
        List{
            Section(header: Text("町名")) {
                TextField("町名を入力",text: $store.name)
            }
            Section(header: Text("メールアドレス")) {
                TextField("メールアドレスを入力",text: $store.email)
                    .textContentType(.emailAddress)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
            }
        }
        .navigationTitle("新規作成")
        .toolbar {
            ToolbarCancelButton {
                store.send(.cancelTapped)
            }
            ToolbarSaveButton(title: "作成") {
                store.send(.createTapped)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .dismissible(backButton: false)
        .loadingOverlay(store.isLoading)
    }
}
