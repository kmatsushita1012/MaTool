import SwiftUI

enum InfoImageColorScheme {
    static func effective(
        systemColorScheme: ColorScheme,
        selectedColorScheme: ColorScheme?
    ) -> ColorScheme {
        selectedColorScheme ?? systemColorScheme
    }

    static func supportsThemeSwitch(lightPath: String?, darkPath: String?) -> Bool {
        guard let lightPath = normalizedPath(lightPath),
              let darkPath = normalizedPath(darkPath) else {
            return false
        }
        return lightPath != darkPath
    }

    static func resolve(
        lightPath: String?,
        darkPath: String?,
        systemColorScheme: ColorScheme
    ) -> ColorScheme {
        switch (isAvailable(lightPath), isAvailable(darkPath)) {
        case (true, false): .light
        case (false, true): .dark
        default: systemColorScheme
        }
    }

    static func imagePath(
        lightPath: String?,
        darkPath: String?,
        colorScheme: ColorScheme
    ) -> String? {
        let candidates = colorScheme == .dark ? [darkPath, lightPath] : [lightPath, darkPath]
        return candidates.compactMap { $0 }.first(where: isAvailable)
    }

    private static func isAvailable(_ path: String?) -> Bool {
        normalizedPath(path) != nil
    }

    private static func normalizedPath(_ path: String?) -> String? {
        guard let path = path?.trimmingCharacters(in: .whitespacesAndNewlines),
              !path.isEmpty,
              let url = URL(string: path),
              url.scheme != nil else {
            return nil
        }
        return path
    }

    static func preferredColorScheme(
        lightPath: String?,
        darkPath: String?,
        systemColorScheme: ColorScheme,
        selectedColorScheme: ColorScheme?
    ) -> ColorScheme {
        switch (isAvailable(lightPath), isAvailable(darkPath)) {
        case (true, false), (false, true), (false, false):
            return resolve(
                lightPath: lightPath,
                darkPath: darkPath,
                systemColorScheme: systemColorScheme
            )
        case (true, true):
            return selectedColorScheme ?? systemColorScheme
        }
    }
}

struct InfoImageThemeToggleButton: View {
    let colorScheme: ColorScheme
    let action: () -> Void

    private var targetColorScheme: ColorScheme {
        colorScheme == .dark ? .light : .dark
    }

    var body: some View {
        if colorScheme == .dark {
            button.tint(.white)
        } else {
            button
        }
    }

    private var button: some View {
        Button(action: action) {
            Image("DarkModeGlyph")
                .renderingMode(.template)
                .font(.system(size: 24))
                .imageScale(.medium)
        }
        .accessibilityLabel(
            targetColorScheme == .dark ? "ダークモードに切り替え" : "ライトモードに切り替え"
        )
    }
}

struct InfoHeaderImageView: View {
    let lightPath: String?
    let darkPath: String?
    let title: String

    @Environment(\.colorScheme) private var colorScheme
    @State private var imageSize: CGSize?
    @State private var loadedImagePath: String?

    private var imagePath: String? {
        InfoImageColorScheme.imagePath(
            lightPath: lightPath,
            darkPath: darkPath,
            colorScheme: colorScheme
        )
    }

    var body: some View {
        if let imagePath {
            WebImageView(imagePath: imagePath, contentMode: .fit) { size in
                imageSize = size
                loadedImagePath = imagePath
            }
                .frame(maxWidth: .infinity)
                .overlay(alignment: .bottomTrailing) {
                    if loadedImagePath == imagePath, let imageSize {
                        InfoImageTitleOverlay(
                            title: title,
                            isVertical: imageSize.height > imageSize.width
                        )
                        .padding(16)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }
}

private struct InfoImageTitleOverlay: View {
    let title: String
    let isVertical: Bool

    @Environment(\.colorScheme) private var colorScheme

    private let outlineOffsets = [
        CGSize(width: -1.5, height: -1.5),
        CGSize(width: 0, height: -1.5),
        CGSize(width: 1.5, height: -1.5),
        CGSize(width: -1.5, height: 0),
        CGSize(width: 1.5, height: 0),
        CGSize(width: -1.5, height: 1.5),
        CGSize(width: 0, height: 1.5),
        CGSize(width: 1.5, height: 1.5)
    ]

    private var outlineColor: Color {
        colorScheme == .light ? .white : .black
    }

    private var directionalShadowColor: Color {
        colorScheme == .light ? .black.opacity(0.72) : .white.opacity(0.72)
    }

    private var titleFont: Font {
        .custom("YujiSyuku-Regular", size: 64, relativeTo: .largeTitle)
    }

    private var titleContent: some View {
        Group {
            if isVertical {
                VStack(spacing: 0) {
                    ForEach(Array(title.enumerated()), id: \.offset) { character in
                        Text(String(character.element))
                    }
                }
            } else {
                Text(title)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
        }
        .font(titleFont)
    }

    var body: some View {
        ZStack {
            titleContent
                .foregroundStyle(outlineColor)
                .shadow(color: outlineColor.opacity(0.65), radius: 4, x: -2, y: -2)
                .shadow(color: directionalShadowColor, radius: 8, x: 4, y: 6)

            ForEach(Array(outlineOffsets.enumerated()), id: \.offset) { item in
                titleContent
                    .foregroundStyle(outlineColor)
                    .offset(x: item.element.width, y: item.element.height)
            }

            titleContent
                .foregroundStyle(.primary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
    }
}

struct InfoImageBlurredBackgroundView: View {
    let lightPath: String?
    let darkPath: String?

    @Environment(\.colorScheme) private var colorScheme

    private var imagePath: String? {
        InfoImageColorScheme.imagePath(
            lightPath: lightPath,
            darkPath: darkPath,
            colorScheme: colorScheme
        )
    }

    var body: some View {
        if let imagePath {
            GeometryReader { proxy in
                WebImageView(imagePath: imagePath, contentMode: .fill)
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .scaleEffect(1.08)
                    .blur(radius: 12)
                    .clipped()
            }
        } else {
            Color.clear
        }
    }
}
