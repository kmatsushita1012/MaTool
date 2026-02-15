//
//  RouteEditView.swift
//  MaTool
//
//  Created by 松下和也 on 2025/08/01.
//

import ComposableArchitecture
import SwiftUI
import NavigationSwipeControl
import Shared

@available(iOS 17.0, *)
struct RouteEditView: View {
    @Dependency(\.values.isLiquidGlassEnabled) var isLiquidGlassEnabled
    
    typealias Tab = RouteEditFeature.Tab
    
    @SwiftUI.Bindable var store: StoreOf<RouteEditFeature>
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
        .toolbar {
            toolbar
        }
        .dismissible(backButton: false, edgeSwipe: false)
        .sheet(item: $store.whole) { item in
            PreviewView(item: item)
        }
        .sheet(item: $store.partial) { item in
            PreviewView(item: item)
        }
        .sheet(item: $store.scope(state: \.point, action: \.point)){ store in
            NavigationStack{
                PointEditView(store: store)
                    .dismissible(backButton: false, edgeSwipe: false)
            }
            .presentationDetents([.fraction(0.3), .fraction(0.5), .large], selection: $selectedDetent)
            .interactiveDismissDisabled()
        }
        .sheet(isPresented: $store.history){
            NavigationStack {
                RouteHistoryView(.init(districtId: store.district.id) {
                    store.send(.sourceSelected($0))
                })
            }
        }
        .alert($store.scope(state: \.alert?.notice, action: \.alert.notice))
        .alert($store.scope(state: \.alert?.delete, action: \.alert.delete))
        .loadingOverlay(store.isLoading)
    }
    
    @ToolbarContentBuilder
    var toolbar: some ToolbarContent {
        ToolbarSaveButton(isDisabled: !store.isSaveable){
            store.send(.saveTapped)
        }
        ToolbarCancelButton {
            store.send(.cancelTapped)
        }
        if #available(iOS 26.0, *), isLiquidGlassEnabled {
            bottomBarAfterLiquidGlass
        } else {
            bottomBarBeforeLiquidGlass
        }
    }
}

// MARK: - LiquidGlass対応前
@available(iOS 17.0, *)
extension RouteEditView {
    @ViewBuilder
    var contentBeforeLiquidGlass: some View {
        VStack {
            tab
                .padding(.horizontal)
            if store.tab == .info {
                info
            } else {
                map
            }
            Spacer()
        }
        .navigationTitle(store.title)
        .navigationBarTitleDisplayMode(.inline)
    }
    
    @ToolbarContentBuilder
    var bottomBarBeforeLiquidGlass: some ToolbarContent {
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
extension RouteEditView {
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
    }
    
    @ToolbarContentBuilder
    @available(iOS 26.0, *)
    var bottomBarAfterLiquidGlass: some ToolbarContent {
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
extension RouteEditView {
    
    @ViewBuilder
    var info: some View {
        List{
            Section {
                Text(store.period.shortText)
            }
            Section(header: Text("説明")) {
                TextEditor(text: $store.route.description.nonOptional)
                    .frame(height:64)
            }
            Section {
                Picker(selection: $store.route.visibility) {
                    ForEach(Visibility.allCases, id: \.self) { option in
                        Text(option.label).tag(option)
                    }
                } label: {
                    Text("公開範囲を選択")
                }
                .pickerStyle(.menu)
            }
            
            Section {
                Button("過去のルートからコピー"){
                    store.send(.copyTapped)
                }
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
        MapView(
            style: store.tab == .public ? .public : .edit,
            points: store.pointEntries,
            region: $store.region,
            size: $store.size,
            pointTapped: { store.send(.pointTapped($0)) },
            onLongPress: { store.send(.mapLongPressed($0)) },
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
                .tag(Tab.edit)
            Text("公開")
                .font(.title)
                .tag(Tab.`public`)
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
    @State var isZooming: Bool = false
    
    @Dependency(\.values.isLiquidGlassEnabled) var isLiquidGlassEnabled: Bool
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack{
            ZoomableImage(image: item.image, isZooming: $isZooming)
                .ignoresSafeArea(isZooming ? .all : [])
                .navigationTitle("プレビュー")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    if isLiquidGlassEnabled {
                        toolbarAfterLiquidGlass
                    } else {
                        toolbarBeforeLiquidGlass
                    }
                }
        }
    }
    
    @ToolbarContentBuilder
    var toolbarBeforeLiquidGlass: some ToolbarContent {
        ToolbarCancelButton {
            dismiss()
        }
        ToolbarItem(placement: .primaryAction) {
            ShareLink(item: item.url) {
                Image(systemName: "square.and.arrow.up")
                    .imageScale(.large)
            }
        }
    }
    
    @ToolbarContentBuilder
    var toolbarAfterLiquidGlass: some ToolbarContent {
        ToolbarCancelButton {
            dismiss()
        }
        ToolbarItem(placement: .primaryAction) {
            ShareLink(item: item.url) {
                Image(systemName: "square.and.arrow.up")
                    .imageScale(.large)
                    .tint(.accentColor)
            }
        }
    }
}

