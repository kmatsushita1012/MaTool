import SwiftUI
import UIKit

struct PasswordTextField<FocusedField: Hashable>: View {
    private let title: LocalizedStringResource
    @Binding private var text: String
    @FocusState.Binding private var focusedField: FocusedField?
    private let field: FocusedField

    @State private var isPasswordVisible = false

    init(
        _ title: LocalizedStringResource,
        text: Binding<String>,
        focusedField: FocusState<FocusedField?>.Binding,
        equals field: FocusedField
    ) {
        self.title = title
        self._text = text
        self._focusedField = focusedField
        self.field = field
    }

    var body: some View {
        PasswordUIKitTextField(
            text: $text,
            placeholder: String(localized: title),
            isSecure: !isPasswordVisible,
            isFocused: focusedField == field,
            onFocusChange: { focusedField = $0 ? field : nil }
        )
        .modifier(AuthTextFieldModifier())
        .overlay(alignment: .trailing) {
            Button {
                isPasswordVisible.toggle()
            } label: {
                Image(systemName: "eye")
                    .opacity(isPasswordVisible ? 0 : 1)
                    .overlay {
                        Image(systemName: "eye.slash")
                            .opacity(isPasswordVisible ? 1 : 0)
                    }
                    .foregroundStyle(.secondary)
                    .padding(8)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(
                isPasswordVisible
                    ? LocalizedStringKey("パスワードを隠す")
                    : LocalizedStringKey("パスワードを表示")
            )
            .padding(.trailing, 8)
        }
    }
}

private struct PasswordUIKitTextField: UIViewRepresentable {
    @Binding var text: String
    let placeholder: String
    let isSecure: Bool
    let isFocused: Bool
    let onFocusChange: (Bool) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> UITextField {
        let textField = UITextField()
        textField.delegate = context.coordinator
        textField.placeholder = placeholder
        textField.text = text
        textField.isSecureTextEntry = isSecure
        textField.textContentType = .password
        textField.keyboardType = .asciiCapable
        textField.autocapitalizationType = .none
        textField.autocorrectionType = .no
        textField.font = .preferredFont(forTextStyle: .body)
        textField.adjustsFontForContentSizeCategory = true
        textField.addTarget(
            context.coordinator,
            action: #selector(Coordinator.textDidChange(_:)),
            for: .editingChanged
        )
        return textField
    }

    func updateUIView(_ textField: UITextField, context: Context) {
        context.coordinator.parent = self
        textField.placeholder = placeholder

        if textField.text != text {
            textField.text = text
        }

        if textField.isSecureTextEntry != isSecure {
            context.coordinator.updateSecureEntry(isSecure, in: textField)
        }

        context.coordinator.updateFocus(isFocused, in: textField)
    }

    func sizeThatFits(
        _ proposal: ProposedViewSize,
        uiView: UITextField,
        context: Context
    ) -> CGSize? {
        CGSize(
            width: proposal.width ?? uiView.intrinsicContentSize.width,
            height: uiView.font?.lineHeight ?? UIFont.preferredFont(forTextStyle: .body).lineHeight
        )
    }

    final class Coordinator: NSObject, UITextFieldDelegate {
        var parent: PasswordUIKitTextField
        private var lastIsFocused: Bool?

        init(_ parent: PasswordUIKitTextField) {
            self.parent = parent
        }

        @objc func textDidChange(_ textField: UITextField) {
            parent.text = textField.text ?? ""
        }

        func textFieldDidBeginEditing(_ textField: UITextField) {
            parent.onFocusChange(true)
        }

        func textFieldDidEndEditing(_ textField: UITextField) {
            parent.onFocusChange(false)
        }

        func updateFocus(_ isFocused: Bool, in textField: UITextField) {
            guard lastIsFocused != isFocused else { return }
            lastIsFocused = isFocused

            if isFocused {
                textField.becomeFirstResponder()
            } else {
                textField.resignFirstResponder()
            }
        }

        func updateSecureEntry(_ isSecure: Bool, in textField: UITextField) {
            let wasFirstResponder = textField.isFirstResponder
            let currentText = textField.text
            let selectionOffsets = textField.selectedTextRange.map {
                (
                    textField.offset(from: textField.beginningOfDocument, to: $0.start),
                    textField.offset(from: textField.beginningOfDocument, to: $0.end)
                )
            }

            textField.isSecureTextEntry = isSecure
            textField.text = currentText

            if let selectionOffsets,
               let start = textField.position(from: textField.beginningOfDocument, offset: selectionOffsets.0),
               let end = textField.position(from: textField.beginningOfDocument, offset: selectionOffsets.1),
               let selection = textField.textRange(from: start, to: end) {
                textField.selectedTextRange = selection
            }

            if wasFirstResponder, !textField.isFirstResponder {
                textField.becomeFirstResponder()
            }
        }
    }
}
