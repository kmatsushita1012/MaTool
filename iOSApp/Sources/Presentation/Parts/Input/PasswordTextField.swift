import SwiftUI

struct PasswordTextField<FocusedField: Hashable>: View {
    private let title: LocalizedStringKey
    @Binding private var text: String
    @FocusState.Binding private var focusedField: FocusedField?
    private let field: FocusedField

    @State private var isPasswordVisible = false

    init(
        _ title: LocalizedStringKey,
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
        Group {
            if isPasswordVisible {
                TextField(title, text: $text)
            } else {
                SecureField(title, text: $text)
            }
        }
        .textContentType(.password)
        .keyboardType(.asciiCapable)
        .textInputAutocapitalization(.never)
        .autocorrectionDisabled()
        .focused($focusedField, equals: field)
        .modifier(AuthTextFieldModifier())
        .overlay(alignment: .trailing) {
            Button {
                isPasswordVisible.toggle()
            } label: {
                Image(systemName: isPasswordVisible ? "eye.slash" : "eye")
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
