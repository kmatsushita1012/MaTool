//
//  FestivalEditView.swift
//  MaTool
//
//  Created by 松下和也 on 2025/04/17.
//

import SwiftUI
import ComposableArchitecture
import NavigationSwipeControl
import Shared

@available(iOS 17.0, *)
struct FestivalEditScreen: View {
    @SwiftUI.Bindable var store: StoreOf<FestivalEditFeature>

    var body: some View {
        WithPerceptionTracking {
            FestivalEditContentView(
                name: $store.festival.name,
                subname: $store.festival.subname,
                prefecture: $store.festival.prefecture,
                city: $store.festival.city,
                description: $store.festival.description.nonOptional,
                baseStatusText: store.base == nil ? "未設定" : "設定済み",
                checkpoints: store.checkpoints,
                hazardSections: store.hazardSections,
                isLoading: store.isLoading,
                onImageEditTapped: { store.send(.imageEditTapped) },
                onBaseTapped: { store.send(.baseTapped) },
                onCheckpointEditTapped: { store.send(.onCheckpointEdit($0)) },
                onCheckpointAddTapped: { store.send(.onCheckpointAdd) },
                onHazardTapped: { store.send(.hazardTapped($0)) },
                onHazardCreateTapped: { store.send(.hazardCreateTapped) },
                onCancelTapped: { store.send(.cancelTapped) },
                onSaveTapped: { store.send(.saveTapped) }
            )
            .sheet(isPresented: $store.isImageEditPresented) {
                NavigationStack {
                    ImageEditContentView(
                        store: store.scope(state: \.imageEdit, action: \.imageEdit),
                        onClose: { store.send(.imageEditDismissTapped) }
                    )
                }
                .navigationBarTitleDisplayMode(.inline)
                .interactiveDismissDisabled(store.imageEdit.isUploading)
            }
            .navigationDestination(
                item: $store.scope(state: \.destination?.base, action: \.destination.base)
            ) { store in
                DistrictBaseEditView(store: store)
            }
            .navigationDestination(
                item: $store.scope(state: \.destination?.checkpoint, action: \.destination.checkpoint)
            ) { store in
                CheckpointEditView(store: store)
            }
            .navigationDestination(
                item: $store.scope(state: \.destination?.hazard, action: \.destination.hazard)
            ) { store in
                HazardSectionView(store: store)
            }
            .dismissible(backButton: false, edgeSwipe: false)
            .alert($store.scope(state: \.alert, action: \.alert))
        }
    }
}

@available(iOS 17.0, *)
typealias FestivalEditView = FestivalEditScreen

@available(iOS 17.0, *)
struct FestivalEditContentView: View {
    @Binding var name: String
    @Binding var subname: String
    @Binding var prefecture: String
    @Binding var city: String
    @Binding var description: String
    let baseStatusText: String
    let checkpoints: [Checkpoint]
    let hazardSections: [HazardSection]
    let isLoading: Bool
    let onImageEditTapped: () -> Void
    let onBaseTapped: () -> Void
    let onCheckpointEditTapped: (Checkpoint) -> Void
    let onCheckpointAddTapped: () -> Void
    let onHazardTapped: (HazardSection) -> Void
    let onHazardCreateTapped: () -> Void
    let onCancelTapped: () -> Void
    let onSaveTapped: () -> Void

    var body: some View {
        List {
            Section(header: Text("祭典名")) {
                TextField("祭典名を入力", text: $name)
            }
            Section(header: Text("本部名")) {
                TextField("本部名を入力", text: $subname)
            }
            Section(header: Text("本部所在地")) {
                NavigationItemView(
                    title: "地図で選択",
                    status: baseStatusText,
                    onTap: onBaseTapped
                )
                .disabled(isLoading)
            }
            Section(header: Text("紹介文")) {
                TextEditor(text: $description)
                    .frame(height: 120)
            }
            Section(header: Text("紹介画像")) {
                Button("画像を変更", systemImage: "photo", action: onImageEditTapped)
                    .disabled(isLoading)
            }
            Section(header: Text("都道府県")) {
                TextField("都道府県を入力", text: $prefecture)
            }
            Section(header: Text("市区町村")) {
                TextField("市区町村を入力", text: $city)
            }
            Section(header: Text("交差点")) {
                ForEach(checkpoints) { checkpoint in
                    NavigationItemView(
                        title: checkpoint.name,
                        onTap: { onCheckpointEditTapped(checkpoint) }
                    )
                    .disabled(isLoading)
                }
                Button("追加", systemImage: "plus.circle", action: onCheckpointAddTapped)
                    .disabled(isLoading)
            }
            Section(header: Text("注釈をつける区間")) {
                ForEach(Array(hazardSections.enumerated()), id: \.offset) { index, hazard in
                    NavigationItemView(
                        title: "\(String(index + 1)). \(hazard.title)",
                        onTap: { onHazardTapped(hazard) }
                    )
                    .disabled(isLoading)
                }
                Button("追加", systemImage: "plus.circle", action: onHazardCreateTapped)
                    .disabled(isLoading)
            }
        }
        .navigationTitle("祭典情報")
        .toolbar {
            ToolbarCancelButton(isDisabled: isLoading, action: onCancelTapped)
            ToolbarSaveButton(isLoading: isLoading, action: onSaveTapped)
        }
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    FestivalEditContentView(
        name: .constant(""),
        subname: .constant(""),
        prefecture: .constant(""),
        city: .constant(""),
        description: .constant(""),
        baseStatusText: "",
        checkpoints: [],
        hazardSections: [],
        isLoading: false,
        onImageEditTapped: {},
        onBaseTapped: {},
        onCheckpointEditTapped: { _ in },
        onCheckpointAddTapped: {},
        onHazardTapped: { _ in },
        onHazardCreateTapped: {},
        onCancelTapped: {},
        onSaveTapped: {}
    )
}
