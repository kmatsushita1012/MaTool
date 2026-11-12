import SwiftUI

struct InfoMaterialContainer<Content: View>: View {
    private let verticalSpacing: CGFloat
    private let content: () -> Content

    init(verticalSpacing: CGFloat = 16, @ViewBuilder content: @escaping () -> Content) {
        self.verticalSpacing = verticalSpacing
        self.content = content
    }

    var body: some View {
        content()
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, verticalSpacing)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(.primary.opacity(0.08), lineWidth: 0.5)
            }
    }
}
