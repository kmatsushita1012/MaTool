import Kingfisher
import SwiftUI
import Shared

struct StoreAdBannerContentView: View {
    let candidate: AdCandidate?
    let isVisible: Bool
    let onImageLoaded: (String) -> Void
    let onImageFailed: (String) -> Void
    let onDismiss: () -> Void

    var body: some View {
        Group {
            if isVisible, let candidate, let url = URL(string: candidate.imagePath) {
                KFImage(url)
                    .onSuccess { _ in onImageLoaded(candidate.impressionId) }
                    .onFailure { _ in onImageFailed(candidate.impressionId) }
                    .resizable()
                    .scaledToFit()
                    .overlay(alignment: .topTrailing) {
                        Button(action: onDismiss) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title3)
                                .symbolRenderingMode(.palette)
                                .foregroundStyle(.white, .black.opacity(0.55))
                                .padding(4)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("広告を閉じる")
                    }
                    .frame(maxWidth: 360)
                    .frame(height: 84)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(radius: 6)
            }
        }
    }
}

#Preview {
    StoreAdBannerContentView(
        candidate: nil,
        isVisible: false,
        onImageLoaded: { _ in },
        onImageFailed: { _ in },
        onDismiss: {}
    )
}
