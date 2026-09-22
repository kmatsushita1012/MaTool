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
    let onPeriodTapped: (Period) -> Void
    let onArchiveTapped: (PeriodYearSection) -> Void

    public init(
        latests: PeriodYearSection?,
        archives: [PeriodYearSection],
        onPeriodTapped: @escaping (Period) -> Void,
        onArchiveTapped: @escaping (PeriodYearSection) -> Void
    ) {
        self.latests = latests
        self.archives = archives
        self.onPeriodTapped = onPeriodTapped
        self.onArchiveTapped = onArchiveTapped
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
    }
}
