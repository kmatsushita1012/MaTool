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

    var body: some View {
        NavigationStack {
            RoutePreviewContentView(
                item: item,
                isZooming: $isZooming,
                isLiquidGlassEnabled: isLiquidGlassEnabled
            )
        }
    }
}
