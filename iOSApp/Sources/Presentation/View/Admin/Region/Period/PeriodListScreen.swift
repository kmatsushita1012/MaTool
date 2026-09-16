//
//  PeriodListScreen.swift
//  MaTool
//  Created by 松下和也 on 2025/12/08.
//

import SwiftUI
import ComposableArchitecture

@available(iOS 17.0, *)
struct PeriodListScreen: View {
    @SwiftUI.Bindable var store: StoreOf<PeriodListFeature>
    @State private var showBatchCreateDialog = false

    var body: some View {
        WithPerceptionTracking {
            PeriodListContentView(
                latests: store.latests,
                archives: store.archives,
                onPeriodTapped: { store.send(.periodTapped($0)) },
                onArchiveTapped: { store.send(.archiveTapped($0)) }
            )
            .toolbar {
                ToolbarAddButton(isDisabled: store.isLoading) {
                    store.send(.periodCreateTapped)
                }
                if !store.yearOptions.isEmpty {
                    if #available(iOS 26.0, *) {
                        ToolbarSpacer(.flexible, placement: .bottomBar)
                    }
                    ToolbarItem(placement: .bottomBar) {
                        Button("一括作成") {
                            showBatchCreateDialog = true
                        }
                        .overlay {
                            if store.isLoading {
                                ProgressView()
                                    .controlSize(.small)
                            }
                        }
                        .disabled(store.isLoading)
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
            .navigationTitle("日程")
            .navigationBarTitleDisplayMode(.inline)
            .fullScreenCover(item: $store.scope(state: \.editDestination, action: \.editDestination)) { destination in
                switch destination.case {
                case .period(let store):
                    PeriodEditScreen(store: store)
                }
            }
            .navigationDestination(item: $store.scope(state: \.destination, action: \.destination)) { destination in
                switch destination.case {
                case .archives(let store):
                    PeriodArchivesScreen(store: store)
                }
            }
            .alert($store.scope(state: \.alert, action: \.alert))
        }
    }
}
