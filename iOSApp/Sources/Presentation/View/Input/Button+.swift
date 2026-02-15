//
//  Button+.swift
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

struct SaveButton: View {
    let title: String
    let action: () -> Void
    
    init(title: String = "保存", action: @escaping () -> Void) {
        self.title = title
        self.action = action
    }
    
    var body: some View {
        Button(title) {
            action()
        }
    }
}

struct ToolbarSaveButton: ToolbarContent {
    let title: String
    let isDisabled: Bool
    let action: () -> Void
    
    init(title: String = "保存", isDisabled: Bool = false, action: @escaping () -> Void) {
        self.title = title
        self.isDisabled = isDisabled
        self.action = action
    }
    
    @Environment(\.isLiquidGlassDisabled) var isLiquidGlassDisabled
 
    var body: some ToolbarContent {
        ToolbarItem(placement: .confirmationAction) {
            if #available(iOS 26.0, *), !isLiquidGlassDisabled {
                SaveButton(title: title) {
                    action()
                }
                .buttonStyle(.glassProminent)
                .disabled(isDisabled)
            } else {
                SaveButton(title: title) {
                    action()
                }
                .disabled(isDisabled)
            }
        }
    }
}

struct DoneButton: View {
    let action: () -> Void
    
    var body: some View {
        Button("完了") {
            action()
        }
    }
}

struct ToolbarDoneButton: ToolbarContent {
    
    let isDisabled: Bool
    let action: () -> Void
    
    init(isDisabled: Bool = false, action: @escaping () -> Void) {
        self.isDisabled = isDisabled
        self.action = action
    }
    
    var body: some ToolbarContent {
        ToolbarItem(placement: .confirmationAction) {
            DoneButton {
                action()
            }
            .disabled(isDisabled)
        }
    }
}

struct CancelButton: View {
    let action: () -> Void
    @Environment(\.isLiquidGlassDisabled) private var isLiquidGlassDisabled

    var body: some View {
        Group {
            if #available(iOS 26.0, *), !isLiquidGlassDisabled {
                Button(systemImage: "xmark", action: action)
            } else {
                Button("キャンセル", action: action)
            }
        }
    }
}
struct ToolbarCancelButton: ToolbarContent {
    let isDisabled: Bool
    let action: () -> Void

    init(isDisabled: Bool = false, action: @escaping () -> Void) {
        self.isDisabled = isDisabled
        self.action = action
    }

    var body: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            CancelButton(action: action)
                .disabled(isDisabled)
        }
    }
}

struct BackButton: View {
    let action: () -> Void
    @Environment(\.isLiquidGlassDisabled) private var isLiquidGlassDisabled

    var body: some View {
        Group {
            if #available(iOS 26.0, *), !isLiquidGlassDisabled {
                Button(systemImage: "chevron.left", action: action)
            } else {
                Button("戻る", action: action)
            }
        }
    }
}

struct ToolbarBackButton: ToolbarContent {
    let isDisabled: Bool
    let action: () -> Void

    init(isDisabled: Bool = false, action: @escaping () -> Void) {
        self.isDisabled = isDisabled
        self.action = action
    }

    var body: some ToolbarContent {
        ToolbarItem(placement: .navigation) {
            BackButton(action: action)
                .disabled(isDisabled)
        }
    }
}

struct AddButton: View {
    let title: String
    let action: () -> Void
    @Environment(\.isLiquidGlassDisabled) private var isLiquidGlassDisabled
    init(title: String = "追加", action: @escaping () -> Void) {
        self.title = title
        self.action = action
    }

    var body: some View {
        Button(title, action: action)
    }
}

struct ToolbarAddButton: ToolbarContent {
    let title: String
    let isDisabled: Bool
    let action: () -> Void

    init(title: String = "追加", isDisabled: Bool = false, action: @escaping () -> Void) {
        self.title = title
        self.isDisabled = isDisabled
        self.action = action
    }

    var body: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            AddButton(title: title, action: action)
                .disabled(isDisabled)
        }
    }
}

