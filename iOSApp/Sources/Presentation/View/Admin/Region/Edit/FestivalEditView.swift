//
//  FestivalEditView.swift
//  MaTool
//
//  Created by 松下和也 on 2025/04/17.
//

import SwiftUI
import ComposableArchitecture
import NavigationSwipeControl

@available(iOS 17.0, *)
struct FestivalEditView: View{
    
    @SwiftUI.Bindable var store: StoreOf<FestivalEditFeature>
    
    var body: some View{
        content
        .navigationTitle("祭典情報")
        .toolbar {
            ToolbarCancelButton {
                store.send(.cancelTapped)
            }
            ToolbarSaveButton {
                store.send(.saveTapped)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .loadingOverlay(store.isLoading)
        .dismissible(backButton: false, edgeSwipe: false)
        .navigationDestination(
            item: $store.scope(state: \.destination?.checkpoint, action:  \.destination.checkpoint)
        ) { store in
            CheckpointEditView(store: store)
        }
        .navigationDestination(
            item: $store.scope(state: \.destination?.hazard, action:  \.destination.hazard)
        ) { store in
            HazardSectionView(store: store)
        }
    }
    
    @ViewBuilder
    var content: some View {
        List {
            Section(header: Text("説明")) {
                TextEditor(text: $store.festival.description.nonOptional)
                    .frame(height:120)
            }
            Section(header: Text("都道府県")) {
                TextField("都道府県を入力",text: $store.festival.prefecture)
            }
            Section(header: Text("市区町村")) {
                TextField("市区町村を入力",text: $store.festival.city)
            }
            Section(header: Text("重要地点")) {
                ForEach(store.checkpoints) { checkpoint in
                    NavigationItemView(
                        title: checkpoint.name,
                        onTap: {
                            store.send(.onCheckpointEdit(checkpoint))
                        }
                    )
                }
                Button("追加", systemImage: "plus.circle") {
                    store.send(.onCheckpointAdd)
                }
            }
            Section(header: Text("注釈をつける区間")) {
                ForEach(Array(store.hazardSections.enumerated()), id: \.offset) { index, hazard in
                    NavigationItemView(
                        title: "\(String(index+1)). \(hazard.title)",
                        onTap: {
                            store.send(.hazardTapped(hazard))
                        }
                    )
                }
                Button("追加", systemImage: "plus.circle") {
                    store.send(.hazardCreateTapped)
                }
            }
        }
    }
}
