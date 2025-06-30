//
//  Untitled.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/04/11.
//

import SwiftUI
import ComposableArchitecture

struct AdminRouteInfoView: View{
    @Bindable var store: StoreOf<AdminRouteInfo>
    
    var body: some View{
        NavigationView{
            Form{
                Section(header: Text("日付")){
                    DatePicker(
                        "日付を選択",
                        selection: $store.route.date.fullDate,
                        displayedComponents: [.date]
                    )
                    .environment(\.locale, Locale(identifier: "ja_JP"))
                }
                Section(header: Text("タイトル")) {
                    TextField("タイトルを入力（例：土曜午前）",text: $store.route.title)
                }
                Section(header: Text("説明")) {
                    TextEditor(text: $store.route.description.nonOptional)
                        .frame(height:60)
                }
                Section(header: Text("経路")) {
                    Button(action: {
                        store.send(.mapTapped)
                    }) {
                        Label("地図で編集", systemImage: "map")
                            .font(.body)
                    }
                }
                Section(header: Text("時刻") ) {
                    DatePicker(
                        "開始時刻",
                        selection: $store.route.start.fullDate,
                        displayedComponents: [.hourAndMinute]
                    )
                    .datePickerStyle(.compact)
                    DatePicker(
                        "終了時刻",
                        selection: $store.route.goal.fullDate,
                        displayedComponents: [.hourAndMinute]
                    )
                    .datePickerStyle(.compact)
                }
                if !store.mode.isCreate {
                    Section {
                        Button(action: {
                            store.send(.deleteTapped)
                        }) {
                            Text("ログアウト")
                                .foregroundColor(.red)
                        }
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("キャンセル") {
                        store.send(.cancelTapped)
                    }
                    .padding(8)
                }
                ToolbarItem(placement: .principal) {
                    Text(store.mode.isCreate ?  "新規作成" : "編集")
                        .bold()
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button{
                        store.send(.saveTapped)
                    } label: {
                        Text("保存")
                            .bold()
                    }
                    .padding(8)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .fullScreenCover(
                item: $store.scope(state: \.destination?.map, action: \.destination.map)
            ) { store in
                AdminRouteMapStoreView(store: store)
            }
            .alert($store.scope(state: \.alert, action: \.alert))
            .loadingOverlay(store.isLoading)
        }
    }
}
