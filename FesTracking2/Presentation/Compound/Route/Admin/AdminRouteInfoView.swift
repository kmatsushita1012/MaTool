//
//  Untitled.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/04/11.
//

import SwiftUI
import ComposableArchitecture

struct AdminRouteInfoView: View{
    @Bindable var store: StoreOf<AdminRouteInfoFeature>
    
    var body: some View{
        NavigationStack{
            Form{
                Section(header: Text("日付")){
                    DatePicker(
                        "日付を選択",
                        selection: Binding(
                            get: { store.route.date.toDate },
                            set: { date in
                                store.send(.binding(.set(\.route.date, SimpleDate.fromDate(date))))
                            }
                        ),
                        displayedComponents: [.date]
                    )
                    .environment(\.locale, Locale(identifier: "ja_JP"))
                }
                Section(header: Text("タイトル")) {
                    TextField("タイトルを入力（土曜午前等）",text: $store.route.title)
                }
                Section(header: Text("説明")) {
                    TextEditor(text: $store.route.description.nonOptional)
                        .frame(height:60)
                }
                
                Section(header: Text("経路")) {
                    Button(action: {
                        store.send(.mapButtonTapped)
                    }) {
                        Label("地図で編集", systemImage: "map")
                            .font(.body)
                    }
                }
                Section(header: Text("公開範囲")) {
                    Picker("公開範囲を選択", selection: $store.route.visibility) {
                        ForEach(Visibility.allCases) { option in
                            Text(option.label).tag(option)
                        }
                    }
                    .pickerStyle(.menu)
                }
                //TODO isONをStateにつくって簡略化
                Section(header: Text("時刻") ) {
                    Toggle("時刻を設定", isOn: Binding(
                        get: { store.route.start != nil },
                        set: { hasTime in
                            store.send(.binding(.set(
                                \.route.start,
                                 hasTime ? SimpleTime.fromDate(Date()) : nil
                            )))
                        }
                    ))
                    if store.route.start != nil {
                        DatePicker(
                            "開始時刻",
                            selection: Binding(
                                get: { store.route.start?.toDate ?? Date() },
                                set: { date in
                                    store.send(.binding(.set(\.route.start, SimpleTime.fromDate(date))))
                                }
                            ),
                            displayedComponents: [.hourAndMinute]
                        )
                        .datePickerStyle(.compact)
                        DatePicker(
                            "終了時刻",
                            selection: Binding(
                                get: { store.route.goal?.toDate ?? Date() },
                                set: { date in
                                    store.send(.binding(.set(\.route.goal, SimpleTime.fromDate(date))))
                                }
                            ),
                            displayedComponents: [.hourAndMinute]
                        )
                        .datePickerStyle(.compact)
                        
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("キャンセル") {
                        store.send(.cancelButtonTapped)
                    }
                    .padding(8)
                }
                ToolbarItem(placement: .principal) {
                    Text("編集")
                        .bold()
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button{
                        store.send(.saveButtonTapped)
                    } label: {
                        Text("保存")
                            .bold()
                    }
                    .padding(8)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .fullScreenCover(
                item: $store.scope(state: \.map, action: \.map)
            ) { store in
                AdminRouteMapView(store: store)
                    .interactiveDismissDisabled(true)
                    .navigationBarBackButtonHidden(true)
            }
        }
        
        .onAppear {
            print("send onAppear")
            store.send(.onAppear)
        }
    }
}
