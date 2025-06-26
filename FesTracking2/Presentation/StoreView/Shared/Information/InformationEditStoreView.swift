//
//  InformationEditStoreView.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/06/25.
//

import SwiftUI
import ComposableArchitecture

struct InformationEditStoreView: View {
    
    @Bindable var store: StoreOf<InformationEdit>
    
    var body: some View {
        NavigationView{
            Form{
                Section(header: Text("名称")) {
                    TextField("名称を入力", text: $store.item.name)
                }
                Section(header: Text("詳細")) {
                    TextEditor(text: $store.item.description.nonOptional)
                        .frame(height:60)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button{
                        store.send(.cancelTapped)
                    } label: {
                        Text("キャンセル")
                    }
                    .padding(.horizontal, 8)
                }
                ToolbarItem(placement: .principal) {
                    Text(store.title)
                        .bold()
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button{
                        store.send(.doneTapped)
                    } label: {
                        Text("完了")
                            .bold()
                    }
                    .padding(.horizontal, 8)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
