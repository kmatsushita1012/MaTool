import SwiftUI

struct HomeContentView<MapView: View, InfoView: View, AccountView: View>: View {
    let selectedTab: HomeFeature.Tab
    let onTabSelected: (HomeFeature.Tab) -> Void
    let accountTitle: String
    private let mapView: () -> MapView
    private let infoView: () -> InfoView
    private let accountView: () -> AccountView

    init(
        selectedTab: HomeFeature.Tab,
        onTabSelected: @escaping (HomeFeature.Tab) -> Void,
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

    var body: some View {
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
                .tag(HomeFeature.Tab.map)

            infoView()
                .tabItem { Label("紹介", systemImage: "info.circle") }
                .tag(HomeFeature.Tab.info)

            accountView()
                .tabItem {
                    Label(accountTitle, systemImage: accountTitle == "設定" ? "gearshape" : "person.badge.key")
                }
                .tag(HomeFeature.Tab.account)
        }
    }
}
