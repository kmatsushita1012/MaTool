//
//  AdminRegionCreateDistrictView.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/05/12.
//

import SwiftUI
import ComposableArchitecture

struct AdminRegionCreateDistrictView: View {
    
    @Bindable var store: StoreOf<AdminRegionDistrictCreate>
    
    var body: some View {
        NavigationStack {
            Form{
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
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("キャンセル") {
                        store.send(.cancelTapped)
                    }
                    .padding(8)
                }
                ToolbarItem(placement: .principal) {
                    Text("新規作成")
                        .bold()
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
        }
    }
}
