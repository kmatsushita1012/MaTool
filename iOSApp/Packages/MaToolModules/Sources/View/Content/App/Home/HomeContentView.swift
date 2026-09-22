import iOSShared
import SwiftUI

public struct HomeContentView<MapView: View, InfoView: View, AccountView: View>: View {
    let selectedTab: HomeTab
    let onTabSelected: (HomeTab) -> Void
    let accountTitle: String
    private let mapView: () -> MapView
    private let infoView: () -> InfoView
    private let accountView: () -> AccountView

    public init(
        selectedTab: HomeTab,
        onTabSelected: @escaping (HomeTab) -> Void,
        accountTitle: String,
        @ViewBuilder mapView: @escaping () -> MapView,
        @ViewBuilder infoView: @escaping () -> InfoView,
        @ViewBuilder accountView: @escaping () -> AccountView
    ) {
        self.selectedTab = selectedTab
        self.onTabSelected = onTabSelected
        self.accountTitle = accountTitle
        self.mapView = mapView
        self.infoView = infoView
        self.accountView = accountView
    }

    public var body: some View {
        tabView
    }

    private var tabView: some View {
        TabView(
            selection: Binding(
                get: { selectedTab },
                set: onTabSelected
            )
        ) {
            mapView()
                .tabItem { Label("地図", systemImage: "map") }
                .tag(HomeTab.map)

            infoView()
                .tabItem { Label("紹介", systemImage: "info.circle") }
                .tag(HomeTab.info)

            accountView()
                .tabItem {
                    Label(accountTitle, systemImage: accountTitle == "設定" ? "gearshape" : "person.badge.key")
                }
                .tag(HomeTab.account)
        }
    }
}
