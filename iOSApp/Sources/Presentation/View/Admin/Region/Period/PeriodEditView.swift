//
//  PeriodEditView.swift
//  MaTool
//
//  Created by 松下和也 on 2025/12/07.
//

import SwiftUI
import ComposableArchitecture
import NavigationSwipeControl
import Shared

@available(iOS 17.0, *)
struct PeriodEditScreen: View {
    @SwiftUI.Bindable var store: StoreOf<PeriodEditFeature>
    
    var body: some View {
        PeriodEditContentView(
            modeTitle: store.mode.title,
            isCreateMode: store.isCreateMode,
            date: Binding(
                get: { store.period.date },
                set: { store.send(.dateChanged($0)) }
            ),
            title: $store.period.title,
            start: $store.period.start,
            end: $store.period.end,
            onCancelTapped: { store.send(.cancelTapped) },
            onSaveTapped: { store.send(.saveTapped) },
            onDeleteTapped: { store.send(.deleteTapped) }
        )
        .loadingOverlay(store.isLoading)
        .alert($store.scope(state: \.alert, action: \.alert))
        .dismissible(backButton: false)
    }
}

@available(iOS 17.0, *)
typealias PeriodEditView = PeriodEditScreen

@available(iOS 17.0, *)
struct PeriodEditContentView: View {
    let modeTitle: String
    let isCreateMode: Bool
    @Binding var date: SimpleDate
    @Binding var title: String
    @Binding var start: SimpleTime
    @Binding var end: SimpleTime
    let onCancelTapped: () -> Void
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
            
            Section{
                Button("削除", systemImage: "trash", role: .destructive) {
                    onDeleteTapped()
                }
                .foregroundStyle(.red)
            }
        }
        .navigationTitle(modeTitle)
        .toolbar{
            ToolbarCancelButton(action: onCancelTapped)
            ToolbarSaveButton(action: onSaveTapped)
        }
    }
}

#Preview {
    PeriodEditContentView(
        modeTitle: "",
        isCreateMode: true,
        date: .constant(.now),
        title: .constant(""),
        start: .constant(.now),
        end: .constant(.now),
        onCancelTapped: {},
        onSaveTapped: {},
        onDeleteTapped: {}
    )
}
