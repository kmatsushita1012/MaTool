//
//  View+LiquidGlass.swift
//  MaTool
//
//  Created by 松下和也 on 2026/01/29.
//

import SwiftUI
import Dependencies

extension ToolbarContent {
    @ToolbarContentBuilder
    func hideSharedBackgroundVisibility() -> some ToolbarContent {
        @Dependency(\.values.isLiquidGlassEnabled) var isLiquidGlassEnabled
        if isLiquidGlassEnabled, #available(iOS 26.0, *) {
            self.sharedBackgroundVisibility(.hidden)
        } else {
            self
        }
    }
}
