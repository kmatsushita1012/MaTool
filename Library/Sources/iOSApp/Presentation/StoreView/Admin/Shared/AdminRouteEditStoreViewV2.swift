//
//  AdminRouteEditStoreViewV2.swift
//  MaTool
//
//  Created by 松下和也 on 2025/08/01.
//

import ComposableArchitecture
import SwiftUI
import NavigationSwipeControl

@available(iOS 17.0, *)
struct AdminRouteEditStoreViewV2: View {
    
    typealias Tab = AdminRouteEditV2.Tab
    
    @SwiftUI.Bindable var store: StoreOf<AdminRouteEditV2>
    @State private var selectedDetent: PresentationDetent = .large
    
    var body: some View {
        VStack {
            Picker("モード", selection: $store.tab) {
                Text("基本情報").tag(Tab.info)
                Text("ルート").tag(Tab.map)
                Text("公開").tag(Tab.pub)
                Text("提出").tag(Tab.export)
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: .infinity)
            
            if store.tab == .info {
                info()
            } else {
                AdminRouteMapViewV2(
                    route: $store.route.readonly,
                    filter: store.filter,
                    onMapLongPress: { store.send(.mapLongPressed($0)) },
                    pointTapped: { store.send(.pointTapped($0)) },
                    region: $store.region,
                    size: $store.size
                )
            }
            Spacer()
        }
        .navigationTitle(store.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button( store.isSaveable ? "キャンセル" : "戻る") {
                    store.send(.cancelTapped)
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("保存") {
                    store.send(.saveTapped)
                }
                .disabled(!store.isSaveable)
                .fontWeight(.bold)
            }
            
            ToolbarItemGroup(placement: .bottomBar) {
                HStack(alignment: .center) {
                    Button {
                        store.send(.undoTapped)
                    } label: {
                        Image(systemName: "arrow.uturn.backward")
                    }
                    .disabled(!store.canUndo)
                    Spacer()
                    Button {
                        store.send(.redoTapped)
                    } label: {
                        Image(systemName: "arrow.uturn.forward")
                    }
                    .disabled(!store.canRedo)
                    Spacer()
                    Button {
                        store.send(.partialTapped)
                    } label: {
                        Image(systemName: "camera")
                    }
                    .disabled(!store.isPartialEnable)
                    Spacer()
                    Button {
                        store.send(.wholeTapped)
                    } label: {
                        Image(systemName: "point.topright.arrow.triangle.backward.to.point.bottomleft.scurvepath")
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal)
                .padding(.vertical, 4)
            }
        }
        .sheet(item: $store.whole) { item in
            NavigationStack {
                PreviewView(item: item)
            }
        }
        .sheet(item: $store.partial) { item in
            NavigationStack {
                PreviewView(item: item)
            }
        }
        .sheet(item: $store.scope(state: \.point, action: \.point)){ store in
            NavigationStack{
                AdminPointEditStoreView(store: store)
                    .dismissible(backButton: false, edgeSwipe: false)
            }
            .presentationDetents([.fraction(0.3), .large], selection: $selectedDetent)
            .interactiveDismissDisabled()
        }
        .alert($store.scope(state: \.alert?.notice, action: \.alert.notice))
        .alert($store.scope(state: \.alert?.delete, action: \.alert.delete))
        .dismissible(backButton: false, edgeSwipe: false)
    }
    
    @ViewBuilder
    func info() -> some View {
        List{
            Section(header: Text("日付")){
                DatePicker(
                    "日付を選択",
                    selection: $store.route.date.fullDate,
                    displayedComponents: [.date]
                )
                .environment(\.locale, Locale(identifier: "ja_JP"))
            }
            Section(header: Text("タイトル")) {
                TextField("タイトルを入力（例：午前）",text: $store.route.title)
            }
            Section(header: Text("説明")) {
                TextEditor(text: $store.route.description.nonOptional)
                    .frame(height:120)
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
            if store.isDeleteable {
                Section {
                    Button(action: {
                        store.send(.deleteTapped)
                    }) {
                        Text("削除")
                            .foregroundColor(.red)
                    }
                }
            }
        }
    }
}

struct PreviewView: View {
    let item: ExportedItem
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZoomableImage(image: item.image)
        .navigationTitle("プレビュー")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("閉じる") {
                    dismiss()
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                ShareLink(item: item.pdf) {
                    Image(systemName: "square.and.arrow.up")
                        .imageScale(.large)
                }
            }
        }
    }
}
