//
//  PeriodEditView.swift
//  MaTool
//
//  Created by 松下和也 on 2025/12/07.
//

import SwiftUI
import ComposableArchitecture
import Shared

struct PeriodEditScreen: View {
    @SwiftUI.Bindable var store: StoreOf<PeriodEditFeature>
    
    var body: some View {
        PeriodEditContentView(
            modeTitle: store.mode.title,
            isCreateMode: store.isCreateMode,
            canDelete: !store.isCreateMode,
            date: Binding(
                get: { store.period.date },
                set: { store.send(.dateChanged($0)) }
            ),
            title: $store.period.title,
            start: $store.period.start,
            end: $store.period.end,
            isLoading: store.isLoading,
            isSaving: store.isSaving,
            isDeleting: store.isDeleting,
            onSaveTapped: { store.send(.saveTapped) },
            onDeleteTapped: { store.send(.deleteTapped) }
        )
        .alert($store.scope(state: \.alert, action: \.alert))
    }
}

typealias PeriodEditView = PeriodEditScreen

struct PeriodEditContentView: View {
    let modeTitle: String
    let isCreateMode: Bool
    let canDelete: Bool
    @Binding var date: SimpleDate
    @Binding var title: String
    @Binding var start: SimpleTime
    @Binding var end: SimpleTime
    let isLoading: Bool
    let isSaving: Bool
    let isDeleting: Bool
    let onSaveTapped: () -> Void
    let onDeleteTapped: () -> Void

    var body: some View {
        Form {
            Section(header: Text("日付")){
                DatePicker(
                    isCreateMode ? "日付を選択" : "日付",
                    selection: $date
                )
                .disabled(!isCreateMode)
            }
            
            Section(header: Text("タイトル"), footer: Text("例: 午前、午後、夜")){
                TextField("タイトルを入力", text: $title)
            }
            
            Section(header: Text("時刻（目安）")){
                TimePicker("開始時刻", selection: $start)
                TimePicker("終了時刻", selection: $end)
            }
            
            if canDelete {
                Section {
                    Button("削除", systemImage: "trash", role: .destructive) {
                        onDeleteTapped()
                    }
                    .loadingIndicator(isLoading: isDeleting)
                    .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle(modeTitle)
        .toolbar {
            ToolbarDoneButton(isDisabled: isLoading || isSaving, action: onSaveTapped)
        }
    }
}

#Preview {
    PeriodEditContentView(
        modeTitle: "",
        isCreateMode: true,
        canDelete: false,
        date: .constant(.now),
        title: .constant(""),
        start: .constant(.now),
        end: .constant(.now),
        isLoading: false,
        isSaving: false,
        isDeleting: false,
        onSaveTapped: {},
        onDeleteTapped: {}
    )
}
