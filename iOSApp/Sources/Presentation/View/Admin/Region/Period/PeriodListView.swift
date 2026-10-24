//
//  PeriodListView.swift
//  MaTool
//
//  Created by 松下和也 on 2025/12/08.
//

import SwiftUI
import ComposableArchitecture
import Shared

@available(iOS 17.0, *)
struct PeriodListScreen: View {
    @SwiftUI.Bindable var store: StoreOf<PeriodListFeature>
    @State private var isBatchCreateDialogPresented = false

    var body: some View {
        WithPerceptionTracking {
            PeriodListContentView(
                latest: store.latests,
                archives: store.archives,
                yearOptions: store.yearOptions,
                createYear: store.createYear,
                isBatchCreateDialogPresented: $isBatchCreateDialogPresented,
                onPeriodTapped: { store.send(.periodTapped($0)) },
                onArchiveTapped: { store.send(.archiveTapped($0)) },
                onPeriodCreateTapped: { store.send(.periodCreateTapped) },
                onBatchCreateTapped: { store.send(.batchCreateTapped($0)) }
            )
            .loadingOverlay(store.isLoading)
            .navigationDestination(item: $store.scope(state: \.destination?.edit, action: \.destination.edit)) {
                PeriodEditView(store: $0)
            }
            .navigationDestination(item: $store.scope(state: \.destination?.archives, action: \.destination.archives)) {
                PeriodArchivesView(store: $0)
            }
            .alert($store.scope(state: \.alert, action: \.alert))
        }
    }
}

@available(iOS 17.0, *)
typealias PeriodListView = PeriodListScreen

@available(iOS 17.0, *)
struct PeriodListContentView: View {
    let latest: PeriodListFeature.State.YearlyPeriods?
    let archives: [PeriodListFeature.State.YearlyPeriods]
    let yearOptions: [Int]
    let createYear: Int
    @Binding var isBatchCreateDialogPresented: Bool
    let onPeriodTapped: (Period) -> Void
    let onArchiveTapped: (PeriodListFeature.State.YearlyPeriods) -> Void
    let onPeriodCreateTapped: () -> Void
    let onBatchCreateTapped: (Int) -> Void

    var body: some View {
        Form {
            if latest == nil && archives.isEmpty {
                Section {
                    ContentUnavailableView {
                        Label("日程がありません", systemImage: "calendar.badge.plus")
                    } description: {
                        Text("右上の追加ボタンから日程を追加できます。")
                    }
                }
            }
            if let latest {
                Section(latest.text) {
                    ForEach(latest.periods) { period in
                        NavigationItemView(title: period.text) {
                            onPeriodTapped(period)
                        }
                    }
                }
            }

            if !archives.isEmpty {
                Section("過去の日程") {
                    ForEach(archives) { archive in
                        NavigationItemView(title: archive.text) {
                            onArchiveTapped(archive)
                        }
                    }
                }
            }
        }
        .navigationTitle("日程")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarAddButton(action: onPeriodCreateTapped)
            batchCreateMenu
        }
    }

    @ToolbarContentBuilder
    private var batchCreateMenu: some ToolbarContent {
        if !yearOptions.isEmpty {
            if #available(iOS 26.0, *) {
                ToolbarSpacer(.flexible, placement: .bottomBar)
            }
            ToolbarItem(placement: .bottomBar) {
                Button("一括作成") {
                    isBatchCreateDialogPresented = true
                }
                .confirmationDialog(
                    "\(String(createYear))年を一括作成",
                    isPresented: $isBatchCreateDialogPresented,
                    titleVisibility: .visible
                ) {
                    ForEach(yearOptions, id: \.self) { year in
                        Button("\(String(year))年") {
                            onBatchCreateTapped(year)
                        }
                    }
                    Button("キャンセル", role: .cancel) {
                        isBatchCreateDialogPresented = false
                    }
                } message: {
                    Text("選択した年の日程をを元に一括で作成します。")
                }
            }
        }
    }
}

#Preview {
    PeriodListContentView(
        latest: nil,
        archives: [],
        yearOptions: [],
        createYear: 2026,
        isBatchCreateDialogPresented: .constant(false),
        onPeriodTapped: { _ in },
        onArchiveTapped: { _ in },
        onPeriodCreateTapped: {},
        onBatchCreateTapped: { _ in }
    )
}
