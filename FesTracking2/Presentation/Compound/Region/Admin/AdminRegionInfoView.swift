//
//  RegionAdmin.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/04/17.
//

import SwiftUI
import ComposableArchitecture

struct AdminRegionInfoView: View{
    
    @Bindable var store: StoreOf<AdminRegionInfoFeature>
    
    var body: some View{
        NavigationStack {
            Form {
                Section(header: Text("祭典名")) {
                    TextField("祭典名を入力",text: $store.item.name)
                }
                Section(header: Text("紹介文")) {
                    TextEditor(text: $store.item.description.nonOptional)
                        .frame(height:120)
                }
                Section(header: Text("都道府県")) {
                    TextField("都道府県を入力",text: $store.item.prefecture)
                }
                Section(header: Text("市区町村")) {
                    TextField("市区町村を入力",text: $store.item.city)
                }
                Section(header: Text("開催日程")) {
                    List(store.item.spans) { span in
                        EditableListItemView(
                            text: span.text(year:false),
                            onEdit: {
                                store.send(.onSpanEdit(span))
                            },
                            onDelete: {
                                store.send(.onSpanDelete(span))
                            })
                        .padding(0)
                    }
                    Button(action: {
                        store.send(.onSpanAdd)
                    }) {
                        Label("追加", systemImage: "plus.circle")
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("キャンセル") {
                        store.send(.cancelButtonTapped)
                    }
                    .padding(8)
                }
                ToolbarItem(placement: .principal) {
                    Text("編集")
                        .bold()
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button{
                        store.send(.saveButtonTapped)
                    } label: {
                        Text("保存")
                            .bold()
                    }
                    .padding(8)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .fullScreenCover(
                item: $store.scope(state: \.span, action: \.span)
            ) { store in
                AdminSpanView(store: store)
            }
        }
    }
}
