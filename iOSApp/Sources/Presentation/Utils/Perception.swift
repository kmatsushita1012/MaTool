//
//  Perception.swift
//  MaTool
//
//  Created by 松下和也 on 2025/09/27.
//

import SwiftUI

struct DismissOnChangeModifier: ViewModifier {
    var isDismissed: Bool
    @Environment(\.dismiss) private var dismiss

    func body(content: Content) -> some View {
        content
            .onChange(of: isDismissed) { newValue in
                if newValue {
                    dismiss()
                }
            }
    }
}

extension View {
    func dismissOnChange(of isDismissed: Bool) -> some View {
        self.modifier(DismissOnChangeModifier(isDismissed: isDismissed))
    }
}
