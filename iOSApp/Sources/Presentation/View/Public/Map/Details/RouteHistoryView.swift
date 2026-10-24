//
//  RouteHistoryView.swift
//  MaTool
//
//  Created by 松下和也 on 2026/01/18.
//

import Shared
import SwiftUI

@available(iOS 17.0, *)
struct RouteHistoryView: View {
    let entries: [RouteEntry]
    let excludingRouteId: Route.ID?
    let selected: (RouteEntry) -> Void

    @Environment(\.dismiss) private var dismiss

    private var groupedByYear: [Int: [RouteEntry]] {
        Dictionary(grouping: entries.filter { $0.id != excludingRouteId }.sorted()) {
            $0.period.date.year
        }
    }

    private var years: [Int] {
        groupedByYear.keys.sorted(by: >)
    }

    var body: some View {
        Form {
            ForEach(years, id: \.self) { year in
                Section("\(String(year))年") {
                    ForEach(groupedByYear[year] ?? []) { entry in
                        Button(entry.period.shortText) {
                            selected(entry)
                        }
                    }
                }
            }
            .foregroundStyle(.primary)
        }
        .navigationTitle("コピー元のルートを選択")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarCancelButton {
                dismiss()
            }
        }
    }
}
