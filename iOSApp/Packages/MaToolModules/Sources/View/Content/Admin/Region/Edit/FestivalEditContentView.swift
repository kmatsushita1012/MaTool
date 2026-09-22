import iOSShared
//
//  FestivalEditContentView.swift
//  MaTool
//

import SwiftUI
import Shared

@available(iOS 17.0, *)
public struct FestivalEditContentView: View {
    @Binding var festival: Festival
    let checkpoints: [Checkpoint]
    let hazardSections: [HazardSection]
    let baseStatusText: String
    let onBaseTapped: () -> Void
    let onCheckpointEdit: (Checkpoint) -> Void
    let onCheckpointAdd: () -> Void
    let onHazardTapped: (HazardSection) -> Void
    let onHazardAdd: () -> Void
    let isLoading: Bool
    let onCancel: () -> Void
    let onSave: () -> Void

    public init(
        festival: Binding<Festival>,
        checkpoints: [Checkpoint],
        hazardSections: [HazardSection],
        baseStatusText: String,
        onBaseTapped: @escaping () -> Void,
        onCheckpointEdit: @escaping (Checkpoint) -> Void,
        onCheckpointAdd: @escaping () -> Void,
        onHazardTapped: @escaping (HazardSection) -> Void,
        onHazardAdd: @escaping () -> Void,
        isLoading: Bool,
        onCancel: @escaping () -> Void,
        onSave: @escaping () -> Void
    ) {
        self._festival = festival
        self.checkpoints = checkpoints
        self.hazardSections = hazardSections
        self.baseStatusText = baseStatusText
        self.onBaseTapped = onBaseTapped
        self.onCheckpointEdit = onCheckpointEdit
        self.onCheckpointAdd = onCheckpointAdd
        self.onHazardTapped = onHazardTapped
        self.onHazardAdd = onHazardAdd
        self.isLoading = isLoading
        self.onCancel = onCancel
        self.onSave = onSave
    }

    public var body: some View {
        List {
            Section(header: Text("祭典名")) {
                TextField("祭典名を入力", text: $festival.name)
            }
            Section(header: Text("本部名")) {
                TextField("本部名を入力", text: $festival.subname)
            }
            Section(header: Text("本部所在地")) {
                NavigationItemView(
                    title: "地図で選択",
                    status: baseStatusText,
                    onTap: onBaseTapped
                )
            }
            Section(header: Text("紹介文")) {
                TextEditor(text: $festival.description.nonOptional)
                    .frame(height: 120)
            }
            Section(header: Text("都道府県")) {
                TextField("都道府県を入力", text: $festival.prefecture)
            }
            Section(header: Text("市区町村")) {
                TextField("市区町村を入力", text: $festival.city)
            }
            Section(header: Text("交差点")) {
                ForEach(checkpoints) { checkpoint in
                    NavigationItemView(
                        title: checkpoint.name,
                        onTap: { onCheckpointEdit(checkpoint) }
                    )
                }
                Button("追加", systemImage: "plus.circle", action: onCheckpointAdd)
            }
            Section(header: Text("注釈をつける区間")) {
                ForEach(Array(hazardSections.enumerated()), id: \.offset) { index, hazard in
                    NavigationItemView(
                        title: "\(index + 1). \(hazard.title)",
                        onTap: { onHazardTapped(hazard) }
                    )
                }
                Button("追加", systemImage: "plus.circle", action: onHazardAdd)
            }
        }
        .navigationTitle("祭典情報")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarCancelButton(action: onCancel)
            ToolbarSaveButton(isLoading: isLoading, action: onSave)
        }
    }
}
