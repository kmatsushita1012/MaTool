import SwiftUI

struct ExpandableTextView: View {
    private static let expandURL = URL(string: "matool://expandable-text/read-more")!

    let text: String
    @State private var isExpanded = false
    @State private var fullTextHeight: CGFloat = 0
    @State private var displayedTextHeight: CGFloat = 0

    private var isTruncated: Bool {
        fullTextHeight > displayedTextHeight + 0.5
    }

    private var displayedText: AttributedString {
        guard !isExpanded, isTruncated else { return AttributedString(text) }

        var content = AttributedString(text + " ")
        var readMore = AttributedString("もっと読む")
        readMore.link = Self.expandURL
        readMore.font = .subheadline.weight(.semibold)
        content.append(readMore)
        return content
    }

    var body: some View {
        Text(displayedText)
            .lineLimit(isExpanded ? nil : 5)
            .truncationMode(isTruncated && !isExpanded ? .middle : .tail)
            .multilineTextAlignment(.leading)
            .environment(
                \.openURL,
                OpenURLAction { url in
                    guard url == Self.expandURL else { return .systemAction }
                    isExpanded = true
                    return .handled
                }
            )
            .background {
                Text(text)
                    .fixedSize(horizontal: false, vertical: true)
                    .hidden()
                    .background {
                        GeometryReader { proxy in
                            Color.clear.preference(
                                key: ExpandableTextFullHeightKey.self,
                                value: proxy.size.height
                            )
                        }
                    }
            }
            .background {
                GeometryReader { proxy in
                    Color.clear.preference(
                        key: ExpandableTextDisplayedHeightKey.self,
                        value: proxy.size.height
                    )
                }
            }
            .onPreferenceChange(ExpandableTextFullHeightKey.self) { fullTextHeight = $0 }
            .onPreferenceChange(ExpandableTextDisplayedHeightKey.self) { displayedTextHeight = $0 }
    }
}

private struct ExpandableTextFullHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private struct ExpandableTextDisplayedHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}
