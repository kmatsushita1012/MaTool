import iOSShared
import Application
import View
//
//  RoutePreviewScreen.swift
//  MaTool
//

import SwiftUI
import Shared
import ComposableArchitecture

struct RoutePreviewScreen: View {
    let item: ExportedItem
    @State private var isZooming = false
    @Dependency(\.values.isLiquidGlassEnabled) var isLiquidGlassEnabled: Bool
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            RoutePreviewContentView(item: item, isZooming: $isZooming)
                .navigationTitle("プレビュー")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarCancelButton {
                        dismiss()
                    }
                    ToolbarItem(placement: .primaryAction) {
                        ShareLink(item: item.url) {
                            Image(systemName: "square.and.arrow.up")
                                .imageScale(.large)
                                .tint(isLiquidGlassEnabled ? .accentColor : nil)
                        }
                    }
                }
        }
    }
}
