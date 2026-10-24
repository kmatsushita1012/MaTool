import ComposableArchitecture
import Dependencies
import SwiftUI

public struct RootSceneView: View {
    @State private var store: StoreOf<RootFeature>
    @Dependency(\.values.isLiquidGlassEnabled) private var isLiquidGlassEnabled

    private var errorStatusBinding: Binding<StatusCheckResult?> {
        Binding(
            get: { store.errorStatus },
            set: { _ in store.send(.statusDismissed) }
        )
    }

    private var normalStatusBinding: Binding<StatusCheckResult?> {
        Binding(
            get: { store.normalStatus },
            set: { _ in store.send(.statusDismissed) }
        )
    }

    public init() {
        if #available(iOS 17.0, *) {
            isPerceptionCheckingEnabled = false
        }
        self._store = State(initialValue: Store(initialState: RootFeature.State()) {
            RootFeature()
        })
    }

    public var body: some View {
        Group {
            switch store.scene {
            case .home:
                if let homeStore = store.scope(state: \.home, action: \.home) {
                    NavigationStack {
                        HomeView(store: homeStore)
                    }
                } else {
                    LoadingView()
                }
            case .onboarding:
                if let onboardingStore = store.scope(state: \.onboarding, action: \.onboarding) {
                    OnboardingView(store: onboardingStore)
                        .preferredColorScheme(.light)
                } else {
                    LoadingView()
                }
            case .loading:
                LoadingView()
                    .preferredColorScheme(.light)
            case .error(let message):
                errorView(message)
            }
        }
        .modifier(AppScrollEdgeEffectModifier(isEnabled: isLiquidGlassEnabled))
        .sheet(item: normalStatusBinding) { status in
            AppStatusModal(status)
        }
        .fullScreenCover(item: errorStatusBinding) { status in
            AppStatusModal(status, canDismiss: false)
        }
        .environment(\.isLiquidGlassDisabled, !isLiquidGlassEnabled)
        .task {
            store.send(.launch)
        }
    }

    @ViewBuilder
    private func errorView(_ message: String) -> some View {
        VStack {
            Spacer()
            Text("申し訳ございません。システムエラーにより停止しています。\n\(message)")
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            Spacer()
        }
    }
}

private struct AppScrollEdgeEffectModifier: ViewModifier {
    let isEnabled: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if isEnabled, #available(iOS 26.0, *) {
            content.scrollEdgeEffectStyle(.soft, for: .top)
        } else {
            content
        }
    }
}

let spanDelta: Double = 0.005
