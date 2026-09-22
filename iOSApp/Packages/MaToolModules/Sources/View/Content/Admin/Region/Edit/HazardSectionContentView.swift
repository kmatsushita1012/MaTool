import iOSShared
//
//  HazardSectionContentView.swift
//  MaTool
//

import SwiftUI
import Shared

@available(iOS 17.0, *)
public struct HazardSectionContentView<MapContent: View>: View {
    @Binding var item: HazardSection
    private let map: () -> MapContent
    let isLiquidGlassEnabled: Bool
    let canUndo: Bool
    let canRedo: Bool
    let onDone: () -> Void
    let onUndo: () -> Void
    let onRedo: () -> Void
    let onDelete: () -> Void

    public init(
        item: Binding<HazardSection>,
        @ViewBuilder map: @escaping () -> MapContent,
        isLiquidGlassEnabled: Bool,
        canUndo: Bool,
        canRedo: Bool,
        onDone: @escaping () -> Void,
        onUndo: @escaping () -> Void,
        onRedo: @escaping () -> Void,
        onDelete: @escaping () -> Void
    ) {
        self._item = item
        self.map = map
        self.isLiquidGlassEnabled = isLiquidGlassEnabled
        self.canUndo = canUndo
        self.canRedo = canRedo
        self.onDone = onDone
        self.onUndo = onUndo
        self.onRedo = onRedo
        self.onDelete = onDelete
    }

    public var body: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading) {
                Text("タイトル")
                    .font(.headline)
                    .foregroundStyle(.gray)
                TextField(
                    "注釈の内容（例: 斜度 5°）",
                    text: $item.title
                )
                .padding()
                .background(.background)
                .clipShape(.capsule)
            }
            map()
                .roundedRect()
        }
        .padding()
        .background {
            Color(UIColor.secondarySystemBackground)
                .ignoresSafeArea(.container, edges: [.bottom, .top])
        }
        .navigationTitle("要注意区間")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarDoneButton(action: onDone)
            if isLiquidGlassEnabled, #available(iOS 26.0, *) {
                ToolbarItemGroup(placement: .bottomBar) {
                    Button("戻る", systemImage: "arrow.uturn.backward", action: onUndo)
                        .disabled(!canUndo)
                    Button("やり直す", systemImage: "arrow.uturn.forward", action: onRedo)
                        .disabled(!canRedo)
                }
                ToolbarSpacer(.flexible, placement: .bottomBar)
                ToolbarItem(placement: .bottomBar) {
                    Button("削除", systemImage: "trash", role: .destructive, action: onDelete)
                        .tint(.red)
                }
            } else {
                ToolbarItem(placement: .bottomBar) {
                    HStack(spacing: 8) {
                        Button("戻る", systemImage: "arrow.uturn.backward", action: onUndo)
                            .disabled(!canUndo)
                        Button("やり直す", systemImage: "arrow.uturn.forward", action: onRedo)
                            .disabled(!canRedo)
                        Spacer()
                        Button("削除", systemImage: "trash", role: .destructive, action: onDelete)
                            .tint(.red)
                    }
                    .padding(.horizontal, 8)
                }
            }
        }
    }
}
