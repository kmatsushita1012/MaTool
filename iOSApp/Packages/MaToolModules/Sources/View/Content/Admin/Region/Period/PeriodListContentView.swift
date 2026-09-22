import iOSShared
//
//  PeriodListContentView.swift
//  MaTool
//

import SwiftUI
import Shared

@available(iOS 17.0, *)
public struct PeriodListContentView: View {
    let latests: PeriodYearSection?
    let archives: [PeriodYearSection]
    let isLoading: Bool
    let yearOptions: [Int]
    let createYear: Int
    let onPeriodTapped: (Period) -> Void
    let onArchiveTapped: (PeriodYearSection) -> Void
    let onCreate: () -> Void
    let onBatchCreate: (Int) -> Void
    @State private var showBatchCreateDialog = false

    public init(
        latests: PeriodYearSection?,
        archives: [PeriodYearSection],
        isLoading: Bool,
        yearOptions: [Int],
        createYear: Int,
        onPeriodTapped: @escaping (Period) -> Void,
        onArchiveTapped: @escaping (PeriodYearSection) -> Void,
        onCreate: @escaping () -> Void,
        onBatchCreate: @escaping (Int) -> Void
    ) {
        self.latests = latests
        self.archives = archives
        self.isLoading = isLoading
        self.yearOptions = yearOptions
        self.createYear = createYear
        self.onPeriodTapped = onPeriodTapped
        self.onArchiveTapped = onArchiveTapped
        self.onCreate = onCreate
        self.onBatchCreate = onBatchCreate
    }

    public var body: some View {
        Form {
            if latests == nil && archives.isEmpty {
                Section {
                    ContentUnavailableView {
                        Label("日程がありません", systemImage: "calendar.badge.plus")
                    } description: {
                        Text("右上の追加ボタンから日程を追加できます。")
                    }
                }
            }
            if let latests {
                Section(latests.text) {
                    ForEach(latests.periods) { period in
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
            ToolbarAddButton(isDisabled: isLoading, action: onCreate)
            if !yearOptions.isEmpty {
                if #available(iOS 26.0, *) {
                    ToolbarSpacer(.flexible, placement: .bottomBar)
                }
                ToolbarItem(placement: .bottomBar) {
                    Button("一括作成") {
                        showBatchCreateDialog = true
                    }
                    .overlay {
                        if isLoading {
                            ProgressView()
                                .controlSize(.small)
                        }
                    }
                    .disabled(isLoading)
                    .confirmationDialog(
                        "\(String(createYear))年を一括作成",
                        isPresented: $showBatchCreateDialog,
                        titleVisibility: .visible
                    ) {
                        ForEach(yearOptions, id: \.self) { year in
                            Button("\(String(year))年") {
                                onBatchCreate(year)
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
}
