//
//  RouteEditInfoContentView.swift
//  MaTool
//

import SwiftUI
import Shared

@available(iOS 17.0, *)
struct RouteEditInfoContentView: View {
    @Binding var route: Route
    let districtName: String
    let mode: RouteEditFeature.EditMode
    let periodText: String
    let timeText: String?
    let passages: [RoutePassage]
    let isAutoPassageDisabled: Bool
    let isDeleteable: Bool
    let onAutoPassage: () -> Void
    let onInsertAbove: (Int) -> Void
    let onInsertBelow: (Int) -> Void
    let onMoveUp: (Int) -> Void
    let onMoveDown: (Int) -> Void
    let onDeletePassage: (Int) -> Void
    let onMovePassages: (IndexSet, Int) -> Void
    let onAddPassage: () -> Void
    let onDeleteRoute: () -> Void

    var body: some View {
        List {
            Section {
                if mode == .preview {
                    LabeledContent("町名", value: districtName)
                }
                LabeledContent("日程", value: periodText)
                if let timeText {
                    LabeledContent("時間", value: timeText)
                }
            } footer: {
                Text("出発・到着時刻は地図編集画面から先頭・末尾のピンで編集してください")
            }
            Section(header: Text("備考（任意）")) {
                TextEditor(text: $route.description.nonOptional)
                    .frame(height: 64)
            }
            Section {
                Picker(selection: $route.visibility) {
                    ForEach(Shared.Visibility.allCases, id: \.self) { option in
                        Text(option.label).tag(option)
                    }
                } label: {
                    Text("公開範囲を選択")
                }
                .pickerStyle(.menu)
            }
            Section {
                Button("自動判定", systemImage: "sparkles", action: onAutoPassage)
                    .disabled(isAutoPassageDisabled)
                    .labelStyle(.titleAndIcon)
                ForEach(passages) { passage in
                    if let index = passages.firstIndex(of: passage) {
                        PassageItemView(
                            passage: passage,
                            canMoveUp: index > 0,
                            canMoveDown: index < passages.count - 1,
                            onInsertAbove: { onInsertAbove(index) },
                            onInsertBelow: { onInsertBelow(index) },
                            onMoveUp: {
                                withAnimation {
                                    onMoveUp(index)
                                }
                            },
                            onMoveDown: {
                                withAnimation {
                                    onMoveDown(index)
                                }
                            },
                            onDelete: {
                                withAnimation {
                                    onDeletePassage(index)
                                }
                            }
                        )
                    }
                }
                .onMove(perform: onMovePassages)
                Button("追加", systemImage: "plus.circle", action: onAddPassage)
                    .labelStyle(.titleAndIcon)
            } header: {
                Text("通過する町")
            } footer: {
                Text("自動判定を実行すると既存の入力は削除されます。結果には誤差が生じる可能性があるので、必ず確認してください。")
            }
            .formStyle(.columns)
            if isDeleteable {
                Section {
                    Button("ルートを削除", systemImage: "trash", role: .destructive, action: onDeleteRoute)
                        .labelStyle(.titleAndIcon)
                }
            }
        }
    }
}
