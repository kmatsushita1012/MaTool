import SwiftUI
import UIKit

struct ExpandableTextView: View {
    let text: String
    @State private var isExpanded = false

    var body: some View {
        ExpandableTextUIKitViewRepresentable(text: text, isExpanded: isExpanded) {
            isExpanded = true
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct ExpandableTextUIKitViewRepresentable: UIViewRepresentable {
    let text: String
    let isExpanded: Bool
    let onExpand: () -> Void

    func makeUIView(context: Context) -> InlineReadMoreUIKitView {
        InlineReadMoreUIKitView()
    }

    func updateUIView(_ uiView: InlineReadMoreUIKitView, context: Context) {
        uiView.text = text
        uiView.isExpanded = isExpanded
        uiView.onExpand = onExpand
        uiView.setNeedsLayout()
    }

    func sizeThatFits(
        _ proposal: ProposedViewSize,
        uiView: InlineReadMoreUIKitView,
        context: Context
    ) -> CGSize? {
        guard let width = proposal.width else { return nil }
        return uiView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
    }
}

private final class InlineReadMoreUIKitView: UIView {
    private struct TextMetrics {
        let lineCount: Int
        let height: CGFloat
        let lineFragmentRects: [CGRect]
    }

    private let lineLimit = 5
    private let itemSpacing: CGFloat = 4
    private let textContainer: NSTextContainer
    private let layoutManager: NSLayoutManager
    private let textStorage: NSTextStorage
    private let textView: UITextView
    private let moreButton = UIButton(type: .custom)

    var text = "" {
        didSet { setNeedsLayout() }
    }

    var isExpanded = false {
        didSet { setNeedsLayout() }
    }

    var onExpand: (() -> Void)?

    override init(frame: CGRect) {
        let textContainer = NSTextContainer(size: .zero)
        let layoutManager = NSLayoutManager()
        let textStorage = NSTextStorage()
        layoutManager.addTextContainer(textContainer)
        textStorage.addLayoutManager(layoutManager)

        self.textContainer = textContainer
        self.layoutManager = layoutManager
        self.textStorage = textStorage
        self.textView = UITextView(frame: .zero, textContainer: textContainer)

        super.init(frame: frame)
        configureViews()
    }

    required init?(coder: NSCoder) {
        let textContainer = NSTextContainer(size: .zero)
        let layoutManager = NSLayoutManager()
        let textStorage = NSTextStorage()
        layoutManager.addTextContainer(textContainer)
        textStorage.addLayoutManager(layoutManager)

        self.textContainer = textContainer
        self.layoutManager = layoutManager
        self.textStorage = textStorage
        self.textView = UITextView(frame: .zero, textContainer: textContainer)

        super.init(coder: coder)
        configureViews()
    }

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        let width = size.width
        guard width > 0 else { return .zero }

        let font = UIFont.preferredFont(forTextStyle: .body)
        let metrics = measureText(width: width, font: font)
        let isTruncated = !isExpanded && metrics.lineCount > lineLimit
        let height: CGFloat
        if isTruncated, let lastVisibleLine = metrics.lineFragmentRects.dropFirst(lineLimit - 1).first {
            height = lastVisibleLine.maxY
        } else {
            height = metrics.height
        }
        return CGSize(width: width, height: height)
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        let width = bounds.width
        guard width > 0 else { return }

        let font = UIFont.preferredFont(forTextStyle: .body)
        textView.frame = bounds
        textView.font = font
        let metrics = measureText(width: width, font: font)
        let isTruncated = !isExpanded && metrics.lineCount > lineLimit
        let buttonSize = configureButton()

        textContainer.size = CGSize(width: width, height: bounds.height)
        textContainer.lineFragmentPadding = 0
        textContainer.maximumNumberOfLines = isTruncated ? lineLimit : 0
        textContainer.lineBreakMode = isTruncated ? .byTruncatingTail : .byWordWrapping

        let finalLineRect: CGRect?
        if isTruncated {
            let lineRect = metrics.lineFragmentRects[lineLimit - 1]
            let exclusionWidth = min(width, buttonSize.width + itemSpacing)
            let exclusionRect = CGRect(
                x: width - exclusionWidth,
                y: lineRect.minY,
                width: exclusionWidth,
                height: lineRect.height
            )
            textContainer.exclusionPaths = [UIBezierPath(rect: exclusionRect)]
            finalLineRect = lineRect
        } else {
            textContainer.exclusionPaths = []
            finalLineRect = nil
        }

        layoutManager.invalidateLayout(
            forCharacterRange: NSRange(location: 0, length: textStorage.length),
            actualCharacterRange: nil
        )
        layoutManager.ensureLayout(for: textContainer)

        guard let finalLineRect else {
            moreButton.isHidden = true
            return
        }

        moreButton.isHidden = false
        moreButton.frame = CGRect(
            x: width - buttonSize.width,
            y: finalLineRect.minY + (finalLineRect.height - buttonSize.height) / 2,
            width: buttonSize.width,
            height: buttonSize.height
        )
    }

    private func configureViews() {
        backgroundColor = .clear
        textContainer.lineFragmentPadding = 0
        textContainer.widthTracksTextView = false

        textView.backgroundColor = .clear
        textView.textContainerInset = .zero
        textView.contentInset = .zero
        textView.isEditable = false
        textView.isSelectable = false
        textView.isScrollEnabled = false
        textView.textAlignment = .natural
        textView.adjustsFontForContentSizeCategory = true

        moreButton.setTitle("もっと読む", for: .normal)
        moreButton.setTitleColor(.systemBlue, for: .normal)
        moreButton.addTarget(self, action: #selector(expandText), for: .touchUpInside)

        addSubview(textView)
        addSubview(moreButton)
    }

    private func configureButton() -> CGSize {
        let buttonFont = UIFontMetrics(forTextStyle: .subheadline)
            .scaledFont(for: .systemFont(ofSize: 15, weight: .semibold))
        moreButton.titleLabel?.font = buttonFont
        moreButton.titleLabel?.adjustsFontForContentSizeCategory = true

        let title = moreButton.title(for: .normal) ?? ""
        let width = (title as NSString).size(withAttributes: [.font: buttonFont]).width
        return CGSize(width: width, height: buttonFont.lineHeight)
    }

    private func measureText(width: CGFloat, font: UIFont) -> TextMetrics {
        guard width > 0, !text.isEmpty else {
            return TextMetrics(lineCount: 0, height: 0, lineFragmentRects: [])
        }

        textContainer.size = CGSize(width: width, height: .greatestFiniteMagnitude)
        textContainer.maximumNumberOfLines = 0
        textContainer.lineBreakMode = .byWordWrapping
        textContainer.exclusionPaths = []
        textStorage.setAttributedString(
            NSAttributedString(
                string: text,
                attributes: [.font: font, .foregroundColor: UIColor.label]
            )
        )
        layoutManager.invalidateLayout(
            forCharacterRange: NSRange(location: 0, length: textStorage.length),
            actualCharacterRange: nil
        )
        layoutManager.ensureLayout(for: textContainer)

        var lineCount = 0
        var height: CGFloat = 0
        var lineFragmentRects: [CGRect] = []
        var glyphIndex = 0
        while glyphIndex < layoutManager.numberOfGlyphs {
            var glyphRange = NSRange(location: NSNotFound, length: 0)
            let lineFragmentRect = layoutManager.lineFragmentRect(
                forGlyphAt: glyphIndex,
                effectiveRange: &glyphRange
            )
            guard glyphRange.length > 0 else { break }

            let usedRect = layoutManager.lineFragmentUsedRect(
                forGlyphAt: glyphIndex,
                effectiveRange: nil
            )
            lineCount += 1
            height = max(height, usedRect.maxY)
            lineFragmentRects.append(lineFragmentRect)
            glyphIndex = NSMaxRange(glyphRange)
        }

        return TextMetrics(
            lineCount: lineCount,
            height: height,
            lineFragmentRects: lineFragmentRects
        )
    }

    @objc private func expandText() {
        onExpand?()
    }
}
