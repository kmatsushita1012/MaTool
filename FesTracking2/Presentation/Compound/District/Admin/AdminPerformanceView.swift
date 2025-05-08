//
//  AdminPerformanceView.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/04/17.
//

import SwiftUI
import ComposableArchitecture

struct AdminPerformanceView:View {
    
    @Bindable var store: StoreOf<PerformanceAdminFeature>
    
    var body: some View {
        NavigationStack{
            Form {
                Section(header: Text("演目名")) {
                    TextField("演目名を入力 (例:〇〇音頭)", text: $store.item.name)
                }
                Section(header: Text("演者")) {
                    TextField("演者を入力 (例:小学生)", text: $store.item.performer)
                }
                Section(header: Text("紹介文")) {
                    TextEditor(text: $store.item.description.nonOptional)
                        .frame(height:120)
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
                    Text("余興編集")
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
