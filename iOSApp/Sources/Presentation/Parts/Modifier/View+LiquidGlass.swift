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

private struct IsLiquidGlassDisabledKey: EnvironmentKey {
    static let defaultValue: Bool = false
}

extension EnvironmentValues {
    var isLiquidGlassDisabled: Bool {
        get { self[IsLiquidGlassDisabledKey.self] }
        set { self[IsLiquidGlassDisabledKey.self] = newValue }
    }
}


