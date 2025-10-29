//
//  AdminRegionCreateDistrictView.swift
//  MaTool
//
//  Created by 松下和也 on 2025/05/12.
//

import SwiftUI
import ComposableArchitecture
import NavigationSwipeControl

@available(iOS 17.0, *)
struct AdminRegionCreateDistrictView: View {
    
    @SwiftUI.Bindable var store: StoreOf<AdminRegionDistrictCreate>
    
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
            ToolbarItem(placement: .topBarLeading) {
                Button("キャンセル") {
                    store.send(.cancelTapped)
                }
                .padding(8)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button{
                    store.send(.createTapped)
                } label: {
                    Text("作成")
                        .bold()
                }
                .padding(8)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .dismissible(backButton: false)
        .loadingOverlay(store.isLoading)
    }
}
