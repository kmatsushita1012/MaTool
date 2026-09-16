import SwiftUI

private struct InfoTitleHeightPreferenceKey: PreferenceKey {
    static let defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private struct InfoScrollOffsetModifier: ViewModifier {
    let onChange: (CGFloat) -> Void

    func body(content: Content) -> some View {
        if #available(iOS 18.0, *) {
            content
                .onScrollGeometryChange(for: CGFloat.self) { geometry in
                    max(0, geometry.contentOffset.y + geometry.contentInsets.top)
                } action: { _, newValue in
                    onChange(newValue)
                }
        } else {
            content
        }
    }
}

private struct InfoScrollBody<Content: View>: View {
    let title: String
    private let content: () -> Content
    let viewportHeight: CGFloat
    let viewportMinY: CGFloat
    let imageBottomY: CGFloat?

    @State private var titleHeight: CGFloat = 0
    @State private var scrollOffset: CGFloat = 0
    @State private var isInlineTitleVisible = false

    private let contentSpacing: CGFloat = 16
    private let minimumVisibleContentRatio: CGFloat = 0.1

    init(
        title: String,
        viewportHeight: CGFloat,
        viewportMinY: CGFloat,
        imageBottomY: CGFloat?,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.viewportHeight = viewportHeight
        self.viewportMinY = viewportMinY
        self.imageBottomY = imageBottomY
        self.content = content
    }

    private var topContentInset: CGFloat {
        let maximumContentTop = viewportHeight * (1 - minimumVisibleContentRatio)
        let contentTop: CGFloat

        guard let imageBottomY else {
            let fallbackContentTop = viewportHeight + contentSpacing
            contentTop = min(fallbackContentTop, maximumContentTop)
            return max(0, contentTop - titleHeight - contentSpacing)
        }

        let imageBottom = imageBottomY - viewportMinY
        contentTop = min(imageBottom + contentSpacing, maximumContentTop)
        return max(0, contentTop - titleHeight - contentSpacing)
    }

    private func contentTopDistance(for offset: CGFloat) -> CGFloat {
        topContentInset + contentSpacing - offset
    }

    private var contentTopDistance: CGFloat {
        contentTopDistance(for: scrollOffset)
    }

    private var titleOffset: CGFloat {
        min(0, contentTopDistance - contentSpacing)
    }

    private func updateInlineTitle(for offset: CGFloat, animated: Bool) {
        let shouldShow = titleHeight > 0
            && contentTopDistance(for: offset) - contentSpacing <= -titleHeight

        guard shouldShow != isInlineTitleVisible else { return }

        if animated {
            withAnimation(.easeInOut(duration: 0.2)) {
                isInlineTitleVisible = shouldShow
            }
        } else {
            isInlineTitleVisible = shouldShow
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: contentSpacing) {
                Color.clear
                    .frame(height: topContentInset)

                content()
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .modifier(InfoScrollOffsetModifier {
            scrollOffset = $0
            updateInlineTitle(for: $0, animated: true)
        })
        .scrollIndicators(.hidden)
        .modifier(SoftTopScrollEdgeEffectModifier())
        .safeAreaInset(edge: .top, alignment: .leading, spacing: 0) {
            HStack(spacing: 0) {
                Text(title)
                    .font(.largeTitle.weight(.bold))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(.regularMaterial, in: Capsule())

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 16)
            .background {
                GeometryReader { proxy in
                    Color.clear
                        .preference(
                            key: InfoTitleHeightPreferenceKey.self,
                            value: proxy.size.height
                        )
                }
            }
            .offset(y: titleOffset)
            .clipped()
        }
        .onPreferenceChange(InfoTitleHeightPreferenceKey.self) {
            titleHeight = $0
            updateInlineTitle(for: scrollOffset, animated: false)
        }
        .navigationTitle(isInlineTitleVisible ? title : "")
        .modifier(InfoInlineToolbarTitleModifier())
    }
}

struct InfoScrollView<Content: View>: View {
    let title: String
    let imageBottomY: CGFloat?
    private let content: () -> Content

    init(
        title: String,
        imageBottomY: CGFloat? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.imageBottomY = imageBottomY
        self.content = content
    }

    var body: some View {
        GeometryReader { proxy in
            InfoScrollBody(
                title: title,
                viewportHeight: proxy.size.height,
                viewportMinY: proxy.frame(in: .global).minY,
                imageBottomY: imageBottomY,
                content: content
            )
        }
    }
}

struct SoftTopScrollEdgeEffectModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.scrollEdgeEffectStyle(.soft, for: .top)
        } else {
            content
        }
    }
}

struct InfoInlineToolbarTitleModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 17.0, *) {
            content.toolbarTitleDisplayMode(.inline)
        } else {
            content.navigationBarTitleDisplayMode(.inline)
        }
    }
}
