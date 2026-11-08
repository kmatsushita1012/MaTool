import Kingfisher
import SwiftUI
import Shared

struct StoreAdBannerScreen: View {
    let candidate: AdCandidate?
    let onImageLoaded: (String) -> Void
    let onImageFailed: (String) -> Void
    let onDismiss: (String) -> Void

    var body: some View {
        if let candidate, let imageURL = URL(string: candidate.imagePath) {
            StoreAdBannerContentView(
                candidate: candidate,
                imageURL: imageURL,
                onImageLoaded: onImageLoaded,
                onImageFailed: onImageFailed,
                onDismiss: onDismiss
            )
        }
    }
}

struct StoreAdBannerContentView: View {
    let candidate: AdCandidate
    let imageURL: URL
    let onImageLoaded: (String) -> Void
    let onImageFailed: (String) -> Void
    let onDismiss: (String) -> Void

    var body: some View {
        KFImage(imageURL)
            .onSuccess { _ in onImageLoaded(candidate.impressionId) }
            .onFailure { _ in onImageFailed(candidate.impressionId) }
            .resizable()
            .scaledToFit()
            .overlay(alignment: .topTrailing) {
                Button { onDismiss(candidate.impressionId) } label: {
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

#Preview {
    StoreAdBannerScreen(
        candidate: nil,
        onImageLoaded: { _ in },
        onImageFailed: { _ in },
        onDismiss: { _ in }
    )
}
