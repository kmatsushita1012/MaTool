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
        modifier(DismissOnChangeModifier(isDismissed: isDismissed))
    }

    @ViewBuilder
    func searchable(text: Binding<String>, prompt: LocalizedStringKey, isEnabled: Bool) -> some View {
        if isEnabled {
            searchable(text: text, prompt: prompt)
        } else {
            self
        }
    }
}
