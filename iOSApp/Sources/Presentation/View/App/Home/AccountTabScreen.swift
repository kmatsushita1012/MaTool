import ComposableArchitecture
import SwiftUI

@available(iOS 17.0, *)
struct AccountTabScreen: View {
    let store: StoreOf<HomeFeature>

    var body: some View {
        WithPerceptionTracking {
            AccountTabContentView {
                if store.isGuest {
                    NavigationStack {
                        SettingsScreen(
                            store: store.scope(state: \.settings, action: \.settings)
                        )
                    }
                } else if let districtStore = store.scope(
                    state: \.adminDistrict,
                    action: \.adminDistrict
                ) {
                    NavigationStack {
                        DistrictDashboardScreen(store: districtStore)
                    }
                } else if let festivalStore = store.scope(
                    state: \.adminFestival,
                    action: \.adminFestival
                ) {
                    NavigationStack {
                        FestivalDashboardScreen(store: festivalStore)
                    }
                } else {
                    ProgressView()
                }
            }
        }
    }
}
