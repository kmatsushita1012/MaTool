//
//  PeriodListContentView.swift
//  MaTool
//

import SwiftUI
import Shared

@available(iOS 17.0, *)
struct PeriodListContentView: View {
    let latests: PeriodListFeature.State.YearlyPeriods?
    let archives: [PeriodListFeature.State.YearlyPeriods]
    let onPeriodTapped: (Period) -> Void
    let onArchiveTapped: (PeriodListFeature.State.YearlyPeriods) -> Void

    var body: some View {
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
    }
}
