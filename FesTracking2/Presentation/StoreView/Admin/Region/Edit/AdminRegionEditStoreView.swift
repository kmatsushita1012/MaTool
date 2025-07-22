//
//  adminRegion.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/04/17.
//

import SwiftUI
import ComposableArchitecture
import NavigationSwipeControl

struct AdminRegionEditView: View{
    
    @Bindable var store: StoreOf<AdminRegionEdit>
    
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
            Section(header: Text("開催日程")) {
                ForEach(store.item.spans) { span in
                    NavigationItemView(
                        title: span.text(year:false),
                        onTap: {
                            store.send(.onSpanEdit(span))
                        }
                    )
                    .padding(0)
                }
                Button(action: {
                    store.send(.onSpanAdd)
                }) {
                    Label("追加", systemImage: "plus.circle")
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            Section(header: Text("経由地")) {
                ForEach(store.item.milestones) { milestone in
                    EditableListItemView(
                        text: milestone.name,
                        onEdit: {
                            store.send(.onMilestoneEdit(milestone))
                        },
                        onDelete: {
                            store.send(.onMilestoneDelete(milestone))
                        }
                    )
                    .padding(0)
                }
                Button(action: {
                    store.send(.onMilestoneAdd)
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
            item: $store.scope(state: \.destination?.span, action: \.destination.span)
        ) { store in
            AdminSpanView(store: store)
        }
        .navigationDestination(
            item: $store.scope(state: \.destination?.milestone, action:  \.destination.milestone)
        ) { store in
            InformationEditStoreView(store: store)
        }
    }
}
