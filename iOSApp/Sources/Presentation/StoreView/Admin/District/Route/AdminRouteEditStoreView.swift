//
//  AdminRouteEditStoreView.swift
//  MaTool
//
//  Created by 松下和也 on 2025/08/01.
//

import ComposableArchitecture
import SwiftUI
import NavigationSwipeControl

@available(iOS 17.0, *)
struct AdminRouteEditStoreView: View {
    @Dependency(\.values.isLiquidGlassEnabled) var isLiquidGlassEnabled
    
    typealias Tab = AdminRouteEdit.Tab
    
    @SwiftUI.Bindable var store: StoreOf<AdminRouteEdit>
    @State private var selectedDetent: PresentationDetent = .large
    @State private var pickerHeight: CGFloat = 0
    
    var body: some View {
        Group{
            if #available(iOS 26.0, *), isLiquidGlassEnabled {
                contentAfterLiquidGlass
            } else {
                contentBeforeLiquidGlass
            }
        }
        .dismissible(backButton: isLiquidGlassEnabled, edgeSwipe: false)
        .sheet(item: $store.whole) { item in
            PreviewView(item: item)
        }
        .sheet(item: $store.partial) { item in
            PreviewView(item: item)
        }
        .sheet(item: $store.scope(state: \.point, action: \.point)){ store in
            NavigationStack{
                AdminPointEditStoreView(store: store)
                    .dismissible(backButton: false, edgeSwipe: false)
            }
            .presentationDetents([.fraction(0.3), .fraction(0.5), .large], selection: $selectedDetent)
            .interactiveDismissDisabled()
        }
        .alert($store.scope(state: \.alert?.notice, action: \.alert.notice))
        .alert($store.scope(state: \.alert?.delete, action: \.alert.delete))
    }
}

// MARK: - LiquidGlass対応前
@available(iOS 17.0, *)
extension AdminRouteEditStoreView {
    @ViewBuilder
    var contentBeforeLiquidGlass: some View {
        VStack {
            tab
            if store.tab == .info {
                info
            } else {
                map
            }
            Spacer()
        }
        .navigationTitle(store.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            toolbarBeforeLiquidGlass
        }
    }
    
    @ToolbarContentBuilder
    var toolbarBeforeLiquidGlass: some ToolbarContent {
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
            HStack(alignment: .center, spacing: 16) {
                undoButton
                redoButton
                Spacer()
                partialButton
                wholeButton
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal)
            .padding(.vertical, 4)
        }
    }
}

// MARK: - LiquidGlass対応後
@available(iOS 17.0, *)
extension AdminRouteEditStoreView {
    @ViewBuilder
    @available(iOS 26.0, *)
    var contentAfterLiquidGlass: some View {
        Group {
            if store.tab == .info {
                info
            } else {
                map
                .ignoresSafeArea(.container, edges: [.bottom, .top])
            }
        }
        .safeAreaInset(edge: .top) {
            tab
                .glassEffect(.regular)
                .padding(.horizontal)
                .padding(.vertical, 8)
        }
        .navigationTitle(store.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            toolbarAfterLiquidGlass
        }
    }
    
    @ToolbarContentBuilder
    @available(iOS 26.0, *)
    var toolbarAfterLiquidGlass: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction){
            Button(systemImage: "checkmark") {
                store.send(.saveTapped)
            }
            .tint(.accentColor)
            .buttonStyle(.borderedProminent)
        }
        ToolbarItemGroup(placement: .bottomBar) {
            undoButton
            redoButton
        }
        ToolbarSpacer(placement: .bottomBar)
        ToolbarItemGroup(placement: .bottomBar){
            partialButton
            wholeButton
        }
    }
}

// MARK: - Common
@available(iOS 17.0, *)
extension AdminRouteEditStoreView {
    
    @ViewBuilder
    var info: some View {
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
    
    @ViewBuilder
    var map: some View {
        AdminRouteMapView(
            route: $store.route.readonly,
            filter: store.filter,
            onMapLongPress: { store.send(.mapLongPressed($0)) },
            pointTapped: { store.send(.pointTapped($0)) },
            region: $store.region,
            size: $store.size
        )
    }
    
    @ViewBuilder
    var tab: some View {
        Picker("モード", selection: $store.tab) {
            Text("基本情報")
                .font(.title)
                .tag(Tab.info)
            Text("ルート")
                .font(.title)
                .tag(Tab.map)
            Text("公開")
                .font(.title)
                .tag(Tab.pub)
        }
        .pickerStyle(.segmented)
        .frame(maxWidth: .infinity)
    }
    
    @ViewBuilder
    var undoButton: some View {
        Button(systemImage: "arrow.uturn.backward") {
            store.send(.undoTapped)
        }
        .disabled(!store.canUndo)
    }
    
    @ViewBuilder
    var redoButton: some View {
        Button(systemImage: "arrow.uturn.forward") {
            store.send(.redoTapped)
        }
        .disabled(!store.canRedo)
    }
    
    @ViewBuilder
    var partialButton: some View {
        Button(systemImage: "camera") {
            store.send(.partialTapped)
        }
        .disabled(!store.isPartialEnable)
    }
    
    @ViewBuilder
    var wholeButton: some View {
        Button(systemImage: "point.topright.arrow.triangle.backward.to.point.bottomleft.scurvepath") {
            store.send(.wholeTapped)
        }
    }
}

struct PreviewView: View {
    let item: ExportedItem
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack{
            ZoomableImage(image: item.image)
                .navigationTitle("プレビュー")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("閉じる") {
                            dismiss()
                        }
                    }
                    ToolbarItem(placement: .primaryAction) {
                        ShareLink(item: item.pdf) {
                            Image(systemName: "square.and.arrow.up")
                                .imageScale(.large)
                        }
                    }
                }
        }
    }
}

