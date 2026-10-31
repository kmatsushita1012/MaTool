import SwiftUI

extension View {
    func loadingIndicator(isLoading: Bool) -> some View {
        disabled(isLoading)
            .overlay {
                if isLoading {
                    ProgressView()
                        .controlSize(.small)
                }
            }
    }
}
