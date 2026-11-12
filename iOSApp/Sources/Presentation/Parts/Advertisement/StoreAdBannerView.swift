import Kingfisher
import SwiftUI
import ComposableArchitecture
import Shared

struct StoreAdBannerView: View {
    @SwiftUI.Bindable var store: StoreOf<StoreAdBannerFeature>

    var body: some View {
        Group {
            if let candidate = store.candidate,
               let imageURL = URL(string: candidate.imagePath) {
                Color.clear
                    .aspectRatio(6.4, contentMode: .fit)
                    .frame(maxWidth: .infinity)
                    .background(.ultraThinMaterial)
                    .overlay {
                        KFImage(imageURL)
                            .onSuccess { _ in store.send(.imageLoaded(candidate.impressionId)) }
                            .onFailure { _ in store.send(.imageFailed(candidate.impressionId)) }
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    .overlay(alignment: .topTrailing) {
                        Button("閉じる", systemImage: "xmark") {
                            store.send(.dismissTapped(candidate.impressionId))
                        }
                        .font(.title)
                        .buttonStyle(.plain)
                        .labelStyle(.iconOnly)
                        .buttonBorderShape(.circle)
                        .contentShape(.rect)
                        .controlSize(.extraLarge)
                        .disabled(!store.isDismissEnabled)
                    }
                }
        }
        .padding()
    }
}
