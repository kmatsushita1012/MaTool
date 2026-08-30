import SwiftUI
import Shared

struct SoftTopScrollEdgeEffectModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.scrollEdgeEffectStyle(.soft, for: .top)
        } else {
            content
        }
    }
}

struct InfoImageBackgroundView: View {
    let lightPath: String?
    let darkPath: String?
    var blurRadius: CGFloat = 8

    @Environment(\.colorScheme) private var colorScheme

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

    var body: some View {
        Group {
            if let imagePath {
                GeometryReader { proxy in
                    ZStack {
                        WebImageView(imagePath: imagePath, contentMode: .fill)
                            .frame(width: proxy.size.width, height: proxy.size.height)
                            .scaleEffect(1.08)
                            .blur(radius: blurRadius)

                        WebImageView(imagePath: imagePath, contentMode: .fit)
                            .frame(width: proxy.size.width, height: proxy.size.height)
                            .shadow(color: .black.opacity(0.2), radius: 12, y: 6)
                    }
                    .clipped()
                }
            } else {
                Color.clear
            }
        }
    }
}

struct ExpandableTextView: View {
    let text: String
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(text)
                .lineLimit(isExpanded ? nil : 5)
                .multilineTextAlignment(.leading)

            if !isExpanded {
                Button("もっと読む") {
                    isExpanded = true
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.tint)
            }
        }
    }
}

struct InfoMaterialContainer<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(.primary.opacity(0.08), lineWidth: 0.5)
            }
    }
}
