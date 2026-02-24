//
//  DistrictEditView.swift
//  MaTool
//
//  Created by 松下和也 on 2025/04/16.
//

import SwiftUI
import PhotosUI
import ComposableArchitecture
import NavigationSwipeControl
import Shared

@available(iOS 17.0, *)
struct DistrictEditView: View {
    @SwiftUI.Bindable var store: StoreOf<DistrictEditFeature>
    
    var body: some View {
        List {
            Section(
                header: Text("町名"),
                footer: Text("IDは更新できません")
            ) {
                TextField("町名を入力",text: $store.district.name)
            }
            Section(header: Text("紹介文")) {
                TextEditor(text: $store.district.description.nonOptional)
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
            Section(header: Text("ルート"), footer: Text("直近のルートの公開範囲が変更されます")) {
                Picker("デフォルトの公開範囲", selection: $store.district.visibility) {
                    ForEach(Visibility.allCases) { option in
                        Text(option.label).tag(option)
                    }
                }
                .pickerStyle(.menu)
            }
            Section(header: Text("余興")) {
                ForEach(store.performances) { item in
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
        .navigationTitle("地区情報")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarCancelButton {
                store.send(.cancelTapped)
            }
            ToolbarSaveButton {
                store.send(.saveTapped)
            }
        }
        .dismissible(backButton: false, edgeSwipe: false)
        .navigationDestination(item: $store.scope(state: \.destination?.base, action: \.destination.base)) { store in
            DistrictBaseEditView(store: store)
        }
        .navigationDestination(item: $store.scope(state: \.destination?.area, action: \.destination.area)) { store in
            DistrictAreaEditView(store: store)
        }
        .navigationDestination(item: $store.scope(state: \.destination?.performance, action: \.destination.performance)) { store in
            PerformanceEditView(store: store)
        }
        .alert($store.scope(state: \.alert, action: \.alert))
        .loadingOverlay(store.isLoading)
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
