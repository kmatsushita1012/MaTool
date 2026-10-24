import SwiftUI

struct InfoScrollView<Content: View>: View {
    private let content: () -> Content

    init(
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.content = content
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                content()
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .modifier(HardTopScrollEdgeEffectModifier())
    }
}

struct HardTopScrollEdgeEffectModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.scrollEdgeEffectStyle(.hard, for: .top)
        } else {
            content
        }
    }
}
