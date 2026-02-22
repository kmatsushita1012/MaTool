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

private struct LiquidGlassSwitch<Base: View, Before: View, After: View>: View {
    @Environment(\.isLiquidGlassDisabled) private var isLiquidGlassDisabled

    let base: Base
    let before: (Base) -> Before
    let after: (Base) -> After

    @ViewBuilder
    var body: some View {
        if isLiquidGlassDisabled {
            before(base)
        } else {
            after(base)
        }
    }
}

extension View {
    func ifLiquidGlass<Before: View, After: View>(
        @ViewBuilder before: @escaping (Self) -> Before,
        @ViewBuilder after: @escaping (Self) -> After
    ) -> some View {
        LiquidGlassSwitch(base: self, before: before, after: after)
    }
    
    func ifLiquidGlass<Before: View>(
        @ViewBuilder before: @escaping (Self) -> Before
    ) -> some View {
        LiquidGlassSwitch(base: self, before: before, after: { _ in self })
    }
    
    func ifLiquidGlass<After: View>(
        @ViewBuilder after: @escaping (Self) -> After
    ) -> some View {
        LiquidGlassSwitch(base: self, before: { _ in self}, after: after)
    }
}
