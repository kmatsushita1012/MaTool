//
//  ProgramListView.swift
//  MaTool
//
//  Created by 松下和也 on 2025/12/08.
//

import SwiftUI
import ComposableArchitecture

@available(iOS 17.0, *)
struct ProgramListView: View {
    @SwiftUI.Bindable var store: StoreOf<ProgramListFeature>
    @Dependency(\.values.isLiquidGlassEnabled) var isLiquidGlassEnabled: Bool
    
    var body: some View {
        content
            .toolbar{
                if isLiquidGlassEnabled {
                    toolbarAfterLiquidGlass
                } else {
                    toolbarBeforeLiquidGlass
                }
            }
            .navigationTitle("日程")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(item: $store.scope(state: \.destination?.edit, action: \.destination.edit)) {
                ProgramEditView(store: $0)
            }
    }
    
    @ViewBuilder
    var content: some View {
        Form {
            if let latest = store.latest {
                Section {
                    NavigationItemView(title: latest.text) {
                        store.send(.programTapped(latest))
                    }
                }
            }
            
            if store.shouldShowArchives {
                Section{
                    ForEach(store.archives){ program in
                        NavigationItemView(title: program.text) {
                            store.send(.programTapped(program))
                        }
                    }
                }
            }
        }
    }
    
    @ToolbarContentBuilder
    var toolbarBeforeLiquidGlass: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Button("追加"){
                store.send(.programCreateTapped)
            }
        }
    }
    
    @ToolbarContentBuilder
    var toolbarAfterLiquidGlass: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            Button(systemImage: "plus") {
                store.send(.programCreateTapped)
            }
        }
    }
}
