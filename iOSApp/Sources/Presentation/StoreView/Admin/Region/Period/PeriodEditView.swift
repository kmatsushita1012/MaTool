//
//  PeriodEditView.swift
//  MaTool
//
//  Created by 松下和也 on 2025/12/07.
//

import SwiftUI
import ComposableArchitecture
import NavigationSwipeControl

@available(iOS 17.0, *)
struct PeriodEditView: View {
    @SwiftUI.Bindable var store: StoreOf<PeriodEditFeature>
    @Dependency(\.values.isLiquidGlassEnabled) var isLiquidGlassEnabled: Bool
    
    var body: some View {
        content
            .navigationTitle(store.mode.title)
            .toolbar{
                ToolbarDoneButton {
                    store.send(.doneTapped)
                }
            }
            .loadingOverlay(store.isLoading)
            .alert($store.scope(state: \.alert, action: \.alert))
    }
    
    @ViewBuilder
    var content: some View {
        Form {
            Section(header: Text("日付")){
                DatePicker(
                    store.isCreateMode ? "日付を選択" : "日付",
                    selection: Binding(get: { store.period.date }, set: { store.send(.dateChanged($0)) })
                )
                .disabled(!store.isCreateMode)
            }
            
            Section(header: Text("タイトル"), footer: Text("例: 午前、午後、夜")){
                TextField("タイトルを入力", text: $store.period.title)
            }
            
            Section(header: Text("時刻（目安）")){
                TimePicker("開始時刻", selection: $store.period.start)
                TimePicker("終了時刻", selection: $store.period.end)
            }
            
            Section{
                Button("削除", systemImage: "trash", role: .destructive) {
                    store.send(.deleteTapped)
                }
                .foregroundStyle(.red)
            }
        }
    }
    
}
