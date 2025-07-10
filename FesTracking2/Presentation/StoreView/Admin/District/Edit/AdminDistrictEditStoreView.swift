//
//  AdminDistrictView.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/04/16.
//

import SwiftUI
import PhotosUI
import ComposableArchitecture

struct AdminDistrictEditView: View {
    @Bindable var store: StoreOf<AdminDistrictEdit>
    
    var body: some View {
        NavigationView{
            Form {
                Section(
                    header: Text("町名"),
                    footer: Text("IDは更新できません")
                ) {
                    TextField("町名を入力",text: $store.item.name)
                }
                Section(header: Text("紹介文")) {
                    TextEditor(text: $store.item.description.nonOptional)
                        .frame(height:120)
                }
                Section(header: Text("会所")) {
                    Button(action: {
                        store.send(.baseTapped)
                    }) {
                        Label("地図で選択", systemImage: "map")
                            .font(.body)
                    }
                }
                Section(header: Text("町域")) {
                    Button(action: {
                        store.send(.areaTapped)
                    }) {
                        Label("地図で選択", systemImage: "map")
                            .font(.body)
                    }
                }
                Section(header: Text("ルート")) {
                    Picker("公開範囲を選択", selection: $store.item.visibility) {
                        ForEach(Visibility.allCases) { option in
                            Text(option.label).tag(option)
                        }
                    }
                    .pickerStyle(.menu)
                }
                Section(header: Text("余興")) {
                    List(store.item.performances) { item in
                        NavigationItemView(
                            title: item.name,
                            onTap: {
                                store.send(.performanceEditTapped(item))
                            }
                        )
                    }
                    Button(action: {
                        store.send(.performanceAddTapped)
                    }) {
                        Label("追加", systemImage: "plus.circle")
                            .frame(maxWidth: .infinity, alignment: .center)
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
                    Text("地区情報")
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
            .fullScreenCover(item: $store.scope(state: \.destination?.base, action: \.destination.base)) { store in
                AdminBaseView(store: store)
            }
            .fullScreenCover(item: $store.scope(state: \.destination?.area, action: \.destination.area)) { store in
                AdminAreaView(store: store)
            }
            .fullScreenCover(item: $store.scope(state: \.destination?.performance, action: \.destination.performance)) { store in
                AdminPerformanceView(store: store)
            }
            .alert($store.scope(state: \.alert, action: \.alert))
        }
    }
}


//                Section(header: Text("画像")) {
//                    PhotosPicker(
//                        selection: $store.image,
//                        matching: .images,
//                        photoLibrary: .shared()) {
//                            HStack {
//                                if let image = store.image {
//                                    Image(uiImage: image)
//                                        .resizable()
//                                        .scaledToFill()
//                                        .frame(width: 80, height: 80)
//                                        .clipShape(Circle())
//                                        .clipped()
//                                } else {
//                                    Text("画像を選択")
//                                }
//                            }
//                        }
//                }
