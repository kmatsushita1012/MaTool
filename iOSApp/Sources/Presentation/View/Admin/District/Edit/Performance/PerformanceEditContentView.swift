//
//  PerformanceEditContentView.swift
//  MaTool
//

import SwiftUI
import Shared

@available(iOS 17.0, *)
struct PerformanceEditContentView: View {
    @Binding var item: Performance
    let isEditable: Bool
    let onDelete: () -> Void

    var body: some View {
        List {
            Section(header: Text("演目名")) {
                TextField("演目名を入力 (例:〇〇音頭)", text: $item.name)
            }
            Section(header: Text("演者")) {
                TextField("演者を入力 (例:小学生)", text: $item.performer)
            }
            Section(header: Text("紹介文")) {
                TextEditor(text: $item.description.nonOptional)
                    .frame(height: 120)
            }
            if isEditable {
                Section {
                    Button("削除", action: onDelete)
                        .foregroundColor(.red)
                }
            }
        }
    }
}
