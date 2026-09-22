import iOSShared
import Shared
import SwiftUI

public struct RootSceneContentView<MainView: View, OnboardingView: View, LoadingView: View>: View {
    let launchState: LaunchState
    private let mainView: () -> MainView
    private let onboardingView: () -> OnboardingView
    private let loadingView: () -> LoadingView

    public init(
        launchState: LaunchState,
        @ViewBuilder mainView: @escaping () -> MainView,
        @ViewBuilder onboardingView: @escaping () -> OnboardingView,
        @ViewBuilder loadingView: @escaping () -> LoadingView
    ) {
        self.launchState = launchState
        self.mainView = mainView
        self.onboardingView = onboardingView
        self.loadingView = loadingView
    }

    @ViewBuilder
    public var body: some View {
        switch launchState {
        case .district, .festival:
            mainView()
        case .onboarding:
            onboardingView()
        case .loading:
            loadingView()
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
