//
//  PeriodListView.swift
//  MaTool
//
//  Created by 松下和也 on 2025/12/08.
//

import SwiftUI
import ComposableArchitecture

@available(iOS 17.0, *)
struct PeriodArchivesView: View {
    @SwiftUI.Bindable var store: StoreOf<PeriodArchivesFeature>
    @Dependency(\.values.isLiquidGlassEnabled) var isLiquidGlassEnabled: Bool
    
    var body: some View {
        content
            .navigationTitle("過去の日程")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(item: $store.scope(state: \.destination?.edit, action: \.destination.edit)) {
                PeriodEditView(store: $0)
            }
    }
    
    @ViewBuilder
    var content: some View {
        Form {
            Section("\(String(store.year))年") {
                ForEach(store.periods) { period in
                    NavigationItemView(title: period.text) {
                        store.send(.periodTapped(period))
                    }
                }
            }
        }
    }
}
