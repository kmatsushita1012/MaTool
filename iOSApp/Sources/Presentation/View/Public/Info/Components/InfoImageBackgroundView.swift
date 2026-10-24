import SwiftUI

struct InfoHeaderImageView: View {
    let lightPath: String?
    let darkPath: String?

    @Environment(\.colorScheme) private var colorScheme

    private var imagePath: String? {
        let candidates = colorScheme == .dark ? [darkPath, lightPath] : [lightPath, darkPath]
        return candidates.compactMap { path in
            guard let path,
                  !path.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  let url = URL(string: path),
                  url.scheme != nil else {
                return nil
            }
            return path
        }.first
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
        let candidates = colorScheme == .dark ? [darkPath, lightPath] : [lightPath, darkPath]
        return candidates.compactMap { path in
            guard let path,
                  !path.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  let url = URL(string: path),
                  url.scheme != nil else {
                return nil
            }
            return path
        }.first
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
