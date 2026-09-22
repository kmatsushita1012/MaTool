import iOSShared
import Application
import View
import ComposableArchitecture
import SwiftUI

@available(iOS 17.0, *)
struct HomeScreen: View {
    @SwiftUI.Bindable var store: StoreOf<HomeFeature>

    var body: some View {
        WithPerceptionTracking {
            HomeContentView(
                selectedTab: store.selectedTab,
                onTabSelected: { store.send(.tabSelected($0)) },
                accountTitle: store.isGuest ? "設定" : "管理者",
                mapView: {
                    MapTabScreen(store: store.scope(state: \.map, action: \.map))
                },
                infoView: {
                    InfoListScreen(store: store.scope(state: \.info, action: \.info))
                },
                accountView: {
                    AccountTabScreen(store: store)
                }
            )
            .alert($store.scope(state: \.alert, action: \.alert))
        }
    }
}
