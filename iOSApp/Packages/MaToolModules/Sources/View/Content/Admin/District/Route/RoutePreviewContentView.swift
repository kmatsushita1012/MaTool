import iOSShared
//
//  RoutePreviewContentView.swift
//  MaTool
//

import SwiftUI
import Shared

public struct RoutePreviewContentView: View {
    let item: ExportedItem
    let isLiquidGlassEnabled: Bool
    @Binding var isZooming: Bool
    @Environment(\.dismiss) private var dismiss

    public init(
        item: ExportedItem,
        isZooming: Binding<Bool>,
        isLiquidGlassEnabled: Bool
    ) {
        self.item = item
        self._isZooming = isZooming
        self.isLiquidGlassEnabled = isLiquidGlassEnabled
    }

    public var body: some View {
        ZoomableImage(image: item.image, isZooming: $isZooming)
            .ignoresSafeArea(isZooming ? .all : [])
            .navigationTitle("プレビュー")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarCancelButton(action: { dismiss() })
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
