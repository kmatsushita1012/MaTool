import iOSShared
//
//  Button+Toolbar.swift
//  MaTool
//
//  Created by 松下和也 on 2025/12/04.
//

import SwiftUI
import Dependencies

extension Button where Label == SwiftUI.Label<Text, Image> {
    init(systemImage: String, action: @escaping @MainActor () -> Void) {
        self.init("", systemImage: systemImage) {
            action()
        }
    }
}

extension Button where Label == Image {
    init(systemImage: String, role: ButtonRole? = nil, action: @escaping @MainActor () -> Void) {
        self.init(role: role,action: action) {
            Image(systemName: systemImage)
        }
    }
}

public struct SaveButton: View {
    let title: String
    let action: () -> Void
    
    public init(title: String = "保存", action: @escaping () -> Void) {
        self.title = title
        self.action = action
    }
    
    public var body: some View {
        Button(title) {
            action()
        }
    }
}

public struct ToolbarSaveButton: ToolbarContent {
    let title: String
    let isDisabled: Bool
    let isLoading: Bool
    let action: () -> Void
    
    public init(
        title: String = "保存",
        isDisabled: Bool = false,
        isLoading: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.isDisabled = isDisabled
        self.isLoading = isLoading
        self.action = action
    }
    
    @Environment(\.isLiquidGlassDisabled) var isLiquidGlassDisabled
 
    public var body: some ToolbarContent {
        ToolbarItem(placement: .confirmationAction) {
            if #available(iOS 26.0, *), !isLiquidGlassDisabled {
                SaveButton(title: title) {
                    action()
                }
                .buttonStyle(.glassProminent)
                .overlay {
                    if isLoading {
                        ProgressView()
                            .controlSize(.small)
                    }
                }
                .disabled(isDisabled || isLoading)
            } else {
                SaveButton(title: title) {
                    action()
                }
                .overlay {
                    if isLoading {
                        ProgressView()
                            .controlSize(.small)
                    }
                }
                .disabled(isDisabled || isLoading)
            }
        }
    }
}

public struct DoneButton: View {
    let action: () -> Void
    
    public var body: some View {
        Button("完了") {
            action()
        }
    }
}

public struct ToolbarDoneButton: ToolbarContent {
    
    let isDisabled: Bool
    let action: () -> Void
    
    public init(isDisabled: Bool = false, action: @escaping () -> Void) {
        self.isDisabled = isDisabled
        self.action = action
    }
    
    public var body: some ToolbarContent {
        ToolbarItem(placement: .confirmationAction) {
            DoneButton {
                action()
            }
            .disabled(isDisabled)
        }
    }
}

public struct CancelButton: View {
    let action: () -> Void
    @Environment(\.isLiquidGlassDisabled) private var isLiquidGlassDisabled

    public var body: some View {
        Group {
            if #available(iOS 26.0, *), !isLiquidGlassDisabled {
                Button(systemImage: "xmark", action: action)
            } else {
                Button("キャンセル", action: action)
            }
        }
    }
}
public struct ToolbarCancelButton: ToolbarContent {
    let isDisabled: Bool
    let action: () -> Void

    public init(isDisabled: Bool = false, action: @escaping () -> Void) {
        self.isDisabled = isDisabled
        self.action = action
    }

    public var body: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            CancelButton(action: action)
                .disabled(isDisabled)
        }
    }
}

public struct BackButton: View {
    let action: () -> Void
    @Environment(\.isLiquidGlassDisabled) private var isLiquidGlassDisabled

    public var body: some View {
        Group {
            if #available(iOS 26.0, *), !isLiquidGlassDisabled {
                Button(systemImage: "chevron.left", action: action)
            } else {
                Button("戻る", action: action)
            }
        }
    }
}

public struct ToolbarBackButton: ToolbarContent {
    let isDisabled: Bool
    let action: () -> Void

    public init(isDisabled: Bool = false, action: @escaping () -> Void) {
        self.isDisabled = isDisabled
        self.action = action
    }

    public var body: some ToolbarContent {
        ToolbarItem(placement: .navigation) {
            BackButton(action: action)
                .disabled(isDisabled)
        }
    }
}

public struct AddButton: View {
    let title: String
    let action: () -> Void
    @Environment(\.isLiquidGlassDisabled) private var isLiquidGlassDisabled
    public init(title: String = "追加", action: @escaping () -> Void) {
        self.title = title
        self.action = action
    }

    public var body: some View {
        Button(title, action: action)
    }
}

public struct ToolbarAddButton: ToolbarContent {
    let title: String
    let isDisabled: Bool
    let action: () -> Void

    public init(title: String = "追加", isDisabled: Bool = false, action: @escaping () -> Void) {
        self.title = title
        self.isDisabled = isDisabled
        self.action = action
    }

    public var body: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            AddButton(title: title, action: action)
                .disabled(isDisabled)
        }
    }
}
