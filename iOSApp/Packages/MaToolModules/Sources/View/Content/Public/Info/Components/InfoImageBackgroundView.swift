import iOSShared
import SwiftUI
import Shared

struct InfoBackgroundImageBottomPreferenceKey: PreferenceKey {
    static let defaultValue: CGFloat? = nil

    static func reduce(value: inout CGFloat?, nextValue: () -> CGFloat?) {
        if let nextValue = nextValue() {
            value = nextValue
        }
    }
}

struct InfoImageBackgroundView: View {
    let lightPath: String?
    let darkPath: String?
    var blurRadius: CGFloat = 8

    @Environment(\.colorScheme) private var colorScheme
    @State private var imageSize: CGSize = .zero

    private var imagePath: String? {
        let candidates: [String?] = switch colorScheme {
        case .dark:
            [darkPath, lightPath]
        default:
            [lightPath, darkPath]
        }

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

    private func fittedImageBottom(in proxy: GeometryProxy) -> CGFloat? {
        let containerSize = proxy.size

        guard imageSize.width > 0,
              imageSize.height > 0,
              containerSize.width > 0,
              containerSize.height > 0 else {
            return nil
        }

        let imageAspectRatio = imageSize.width / imageSize.height
        let containerAspectRatio = containerSize.width / containerSize.height
        let fittedHeight: CGFloat

        if imageAspectRatio > containerAspectRatio {
            fittedHeight = containerSize.width / imageAspectRatio
        } else {
            fittedHeight = containerSize.height
        }

        let topInset = (containerSize.height - fittedHeight) / 2
        return proxy.frame(in: .global).minY + topInset + fittedHeight
    }

    var body: some View {
        Group {
            if let imagePath {
                GeometryReader { proxy in
                    ZStack {
                        WebImageView(imagePath: imagePath, contentMode: .fill)
                            .frame(width: proxy.size.width, height: proxy.size.height)
                            .scaleEffect(1.08)
                            .blur(radius: blurRadius)

                        WebImageView(
                            imagePath: imagePath,
                            contentMode: .fit,
                            onImageLoaded: { imageSize = $0 }
                        )
                            .frame(width: proxy.size.width, height: proxy.size.height)
                            .shadow(color: .black.opacity(0.2), radius: 12, y: 6)

                        Color.clear
                            .preference(
                                key: InfoBackgroundImageBottomPreferenceKey.self,
                                value: fittedImageBottom(in: proxy)
                            )
                    }
                    .clipped()
                }
            } else {
                Color.clear
            }
        }
    }
}
