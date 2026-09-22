import iOSShared
//
//  PeriodEditContentView.swift
//  MaTool
//

import SwiftUI
import Shared

@available(iOS 17.0, *)
public struct PeriodEditContentView: View {
    @Binding var period: Period
    let isCreateMode: Bool
    let onDateChanged: (SimpleDate) -> Void
    let onDelete: () -> Void
    let title: String
    let isLoading: Bool
    let onCancel: () -> Void
    let onSave: () -> Void

    public init(
        period: Binding<Period>,
        isCreateMode: Bool,
        onDateChanged: @escaping (SimpleDate) -> Void,
        onDelete: @escaping () -> Void,
        title: String,
        isLoading: Bool,
        onCancel: @escaping () -> Void,
        onSave: @escaping () -> Void
    ) {
        self._period = period
        self.isCreateMode = isCreateMode
        self.onDateChanged = onDateChanged
        self.onDelete = onDelete
        self.title = title
        self.isLoading = isLoading
        self.onCancel = onCancel
        self.onSave = onSave
    }

    public var body: some View {
        Form {
            Section(header: Text("日付")) {
                DatePicker(
                    isCreateMode ? "日付を選択" : "日付",
                    selection: Binding(
                        get: { period.date },
                        set: onDateChanged
                    )
                )
                .disabled(!isCreateMode)
            }
            Section(header: Text("タイトル"), footer: Text("例: 午前、午後、夜")) {
                TextField("タイトルを入力", text: $period.title)
            }
            Section(header: Text("時刻（目安）")) {
                TimePicker("開始時刻", selection: $period.start)
                TimePicker("終了時刻", selection: $period.end)
            }
            Section {
                Button("削除", systemImage: "trash", role: .destructive, action: onDelete)
                    .foregroundStyle(.red)
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarCancelButton(action: onCancel)
            ToolbarSaveButton(isLoading: isLoading, action: onSave)
        }
    }
}
