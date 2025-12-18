//
//  AdminFestivalEdit.swift
//  MaTool
//
//  Created by 松下和也 on 2025/04/17.
//

import SwiftUI
import ComposableArchitecture
import NavigationSwipeControl

@available(iOS 17.0, *)
struct AdminFestivalEditView: View{
    
    @SwiftUI.Bindable var store: StoreOf<AdminFestivalEdit>
    
    var body: some View{
        List {
            Section(header: Text("説明")) {
                TextEditor(text: $store.item.description.nonOptional)
                    .frame(height:120)
            }
            Section(header: Text("都道府県")) {
                TextField("都道府県を入力",text: $store.item.prefecture)
            }
            Section(header: Text("市区町村")) {
                TextField("市区町村を入力",text: $store.item.city)
            }
            Section(header: Text("経由地")) {
                ForEach(store.item.checkpoints) { checkpoint in
                    EditableListItemView(
                        text: checkpoint.name,
                        onEdit: {
                            store.send(.onCheckpointEdit(checkpoint))
                        },
                        onDelete: {
                            store.send(.onCheckpointDelete(checkpoint))
                        }
                    )
                    .padding(0)
                }
                Button(action: {
                    store.send(.onCheckpointAdd)
                }) {
                    Label("追加", systemImage: "plus.circle")
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
        }
        .navigationTitle("祭典情報")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("キャンセル") {
                    store.send(.cancelTapped)
                }
                .padding(8)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button{
                    store.send(.saveTapped)
                } label: {
                    Text("保存")
                        .bold()
                }
                .padding(8)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .loadingOverlay(store.isLoading)
        .dismissible(backButton: false, edgeSwipe: false)
        .navigationDestination(
            item: $store.scope(state: \.destination?.checkpoint, action:  \.destination.checkpoint)
        ) { store in
            InformationEditStoreView(store: store)
        }
    }
}
