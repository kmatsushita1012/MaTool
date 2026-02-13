//
//  PeriodListView.swift
//  MaTool
//
//  Created by 松下和也 on 2025/12/08.
//

import SwiftUI
import ComposableArchitecture

@available(iOS 17.0, *)
struct PeriodListView: View {
    @SwiftUI.Bindable var store: StoreOf<PeriodListFeature>
    @Dependency(\.values.isLiquidGlassEnabled) var isLiquidGlassEnabled: Bool
    @State private var showBatchCreateDialog = false
    
    var body: some View {
        content
            .toolbar{
                toolbar
            }
            .navigationTitle("日程")
            .navigationBarTitleDisplayMode(.inline)
            .loadingOverlay(store.isLoading)
            .navigationDestination(item: $store.scope(state: \.destination?.edit, action: \.destination.edit)) {
                PeriodEditView(store: $0)
            }
            .navigationDestination(item: $store.scope(state: \.destination?.archives, action: \.destination.archives)) {
                PeriodArchivesView(store: $0)
            }
            .alert($store.scope(state: \.alert, action: \.alert))
    }
    
    @ViewBuilder
    var content: some View {
        Form {
            if let latest = store.latests {
                Section(latest.text) {
                    ForEach(latest.periods) { period in
                        NavigationItemView(title: period.text) {
                            store.send(.periodTapped(period))
                        }
                    }
                }
            }
            
            if !store.archives.isEmpty {
                Section("過去の日程"){
                    ForEach(store.archives){ archive in
                        NavigationItemView(title: archive.text) {
                            store.send(.archiveTapped(archive))
                        }
                    }
                }
            }
        }
    }
    
    @ToolbarContentBuilder
    var toolbar: some ToolbarContent {
        ToolbarAddButton {
            store.send(.periodCreateTapped)
        }
        batchCreateMenu
    }
    
    @ToolbarContentBuilder
    var batchCreateMenu: some ToolbarContent {
        if !store.yearOptions.isEmpty {
            if #available(iOS 26.0, *) {
                ToolbarSpacer(.flexible, placement: .bottomBar)
            }
            ToolbarItem(placement: .bottomBar) {
                Button("一括作成") {
                    showBatchCreateDialog = true
                }
                .confirmationDialog(
                    "\(String(store.createYear))年を一括作成",
                    isPresented: $showBatchCreateDialog,
                    titleVisibility: .visible
                ) {
                    ForEach(store.yearOptions, id: \.self) { year in
                        Button("\(String(year))年") {
                            store.send(.batchCreateTapped(year))
                        }
                    }
                    Button("キャンセル", role: .cancel) {
                        showBatchCreateDialog = false
                    }
                } message: {
                    Text("選択した年の日程をを元に一括で作成します。")
                }
            }
        }
    }
}
