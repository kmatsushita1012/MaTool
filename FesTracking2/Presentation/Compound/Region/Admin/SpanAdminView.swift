//
//  SpanAdminView.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/04/17.
//

import SwiftUI
import ComposableArchitecture

struct SpanAdminView:View{
    @Bindable var store:StoreOf<SpanAdminFeature>
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("日付")) {
                    DatePicker(
                        "日付",
                        selection: $store.date,
                        displayedComponents: [.date]
                    )
                    .environment(\.locale, Locale(identifier: "ja_JP"))
                }
                Section(header: Text("時刻")) {
                    DatePicker(
                        "開始時刻",
                        selection: $store.start,
                        displayedComponents: [.hourAndMinute]
                    )
                    DatePicker(
                        "終了時刻",
                        selection: $store.end,
                        displayedComponents: [.hourAndMinute]
                    )
                    .datePickerStyle(.compact)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button{
                        store.send(.cancelButtonTapped)
                    } label: {
                        Text("キャンセル")
                    }
                    .padding(.horizontal, 8)
                }
                ToolbarItem(placement: .principal) {
                    Text("地点編集")
                        .bold()
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button{
                        store.send(.doneButtonTapped)
                    } label: {
                        Text("完了")
                            .bold()
                    }
                    .padding(.horizontal, 8)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
