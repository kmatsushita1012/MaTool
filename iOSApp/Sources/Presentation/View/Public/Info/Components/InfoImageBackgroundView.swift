import SwiftUI

enum InfoImageColorScheme {
    static func effective(
        systemColorScheme: ColorScheme,
        selectedColorScheme: ColorScheme?
    ) -> ColorScheme {
        selectedColorScheme ?? systemColorScheme
    }

    static func supportsThemeSwitch(lightPath: String?, darkPath: String?) -> Bool {
        isAvailable(lightPath) && isAvailable(darkPath)
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
        guard let path,
              !path.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let url = URL(string: path),
              url.scheme != nil else {
            return false
        }
        return true
    }

    static func preferredColorScheme(
        lightPath: String?,
        darkPath: String?,
        systemColorScheme: ColorScheme,
        selectedColorScheme: ColorScheme?
    ) -> ColorScheme {
        guard supportsThemeSwitch(lightPath: lightPath, darkPath: darkPath) else {
            return resolve(
                lightPath: lightPath,
                darkPath: darkPath,
                systemColorScheme: systemColorScheme
            )
        }
        return effective(
            systemColorScheme: systemColorScheme,
            selectedColorScheme: selectedColorScheme
        )
    }
}

struct InfoImageThemeToggleButton: View {
    let colorScheme: ColorScheme
    let action: () -> Void

    private var targetColorScheme: ColorScheme {
        colorScheme == .dark ? .light : .dark
    }

    var body: some View {
        Button(action: action) {
            // Temporary placeholder until the custom symbol is provided.
            Image(systemName: "circle.lefthalf.filled")
        }
        .accessibilityLabel(
            targetColorScheme == .dark ? "ダークモードに切り替え" : "ライトモードに切り替え"
        )
    }
}

struct InfoHeaderImageView: View {
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
            WebImageView(imagePath: imagePath, contentMode: .fit)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
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
