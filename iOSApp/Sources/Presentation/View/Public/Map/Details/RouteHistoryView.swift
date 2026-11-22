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
    let history: [EditionRouteGroup]
    let excludingRouteId: Route.ID?
    var isLoading = false
    let selected: (RouteEntry) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Form {
            ForEach(history, id: \.edition.id) { history in
                Section("\(String(history.edition.year))年") {
                    ForEach(history.entries.filter { $0.id != excludingRouteId }) { entry in
                        Button(entry.period.shortText) {
                            selected(entry)
                        }
                        .disabled(isLoading)
                    }
                }
            }
            .foregroundStyle(.primary)
        }
        .navigationTitle("コピー元のルートを選択")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarCancelButton(isDisabled: isLoading) {
                dismiss()
            }
        }
    }
}
