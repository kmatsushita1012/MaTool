import ComposableArchitecture
import Shared
import SwiftUI

public struct RootSceneView: View {
    @Shared var launchState: LaunchState
    @Perception.Bindable var store: StoreOf<RootSceneFeature>
    @Dependency(\.values.isLiquidGlassEnabled) var isLiquidGlassEnabled

    public init() {
        let launchState = Shared(value: LaunchState.loading)
        self._launchState = launchState
        self.store = Store(
            initialState: RootSceneFeature.State(launchState: launchState)
        ) {
            RootSceneFeature()
        }
    }

    public var body: some View {
        WithPerceptionTracking {
            let currentLaunchState = store.launchState
            let status = store.status
            let isError: Bool = {
                if case .error = currentLaunchState {
                    return true
                }
                return false
            }()

            RootSceneContentView(
                launchState: currentLaunchState,
                mainView: {
                    if #available(iOS 17.0, *),
                       let homeStore = store.scope(state: \.home, action: \.home) {
                        HomeScreen(store: homeStore)
                    } else {
                        LoadingView()
                    }
                },
                onboardingView: {
                    OnboardingView(
                        store: Store(
                            initialState: OnboardingFeature.State(
                                launchState: $launchState
                            )
                        ) {
                            OnboardingFeature()
                        }
                    )
                    .preferredColorScheme(.light)
                },
                loadingView: {
                    LoadingView()
                        .preferredColorScheme(.light)
                }
            )
            .sheet(
                item: Binding(
                    get: { isError ? nil : status },
                    set: { _ in store.send(.statusDismissed) }
                )
            ) { status in
                AppStatusModal(status)
            }
            .fullScreenCover(
                item: Binding(
                    get: { isError ? status : nil },
                    set: { _ in store.send(.statusDismissed) }
                )
            ) { status in
                AppStatusModal(status, canDismiss: false)
            }
            .environment(\.isLiquidGlassDisabled, !isLiquidGlassEnabled)
            .task {
                store.send(.start)
            }
            .onChange(of: store.launchState) { _ in
                store.send(.launchStateChanged)
            }
        }
    }

}

struct RootSceneContentView<MainView: View, OnboardingView: View, LoadingView: View>: View {
    let launchState: LaunchState
    let mainView: MainView
    let onboardingView: OnboardingView
    let loadingView: LoadingView

    init(
        launchState: LaunchState,
        @ViewBuilder mainView: () -> MainView,
        @ViewBuilder onboardingView: () -> OnboardingView,
        @ViewBuilder loadingView: () -> LoadingView
    ) {
        self.launchState = launchState
        self.mainView = mainView()
        self.onboardingView = onboardingView()
        self.loadingView = loadingView()
    }

    @ViewBuilder
    var body: some View {
        switch launchState {
        case .district, .festival:
            mainView
        case .onboarding:
            onboardingView
        case .loading:
            loadingView
        case .error(let message):
            VStack {
                Spacer()
                Text("申し訳ございません。システムエラーにより停止しています。\n\(message)")
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                Spacer()
            }
        }
    }
}
