import ComposableArchitecture
import Shared
import SwiftUI

struct PeriodDraftEditView: View {
    @SwiftUI.Bindable var store: StoreOf<PeriodDraftEditFeature>

    var body: some View {
        PeriodDraftEditContentView(
            isCreateMode: store.isCreateMode,
            date: Binding(
                get: { store.period.date },
                set: { store.send(.dateChanged($0)) }
            ),
            title: $store.period.title,
            start: $store.period.start,
            end: $store.period.end,
            onSaveTapped: { store.send(.saveTapped) },
            onDeleteTapped: { store.send(.deleteTapped) }
        )
    }
}

private struct PeriodDraftEditContentView: View {
    let isCreateMode: Bool
    @Binding var date: SimpleDate
    @Binding var title: String
    @Binding var start: SimpleTime
    @Binding var end: SimpleTime
    let onSaveTapped: () -> Void
    let onDeleteTapped: () -> Void

    var body: some View {
        Form {
            Section(header: Text("日付")) {
                DatePicker(
                    isCreateMode ? "日付を選択" : "日付",
                    selection: $date
                )
                .disabled(!isCreateMode)
            }

            Section(header: Text("タイトル"), footer: Text("例: 午前、午後、夜")) {
                TextField("タイトルを入力", text: $title)
            }

            Section(header: Text("時刻（目安）")) {
                TimePicker("開始時刻", selection: $start)
                TimePicker("終了時刻", selection: $end)
            }

            if !isCreateMode {
                Section {
                    Button("削除", systemImage: "trash", role: .destructive, action: onDeleteTapped)
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle(isCreateMode ? "日程を追加" : "日程を編集")
        .toolbar {
            ToolbarDoneButton(isDisabled: false, action: onSaveTapped)
        }
    }
}
