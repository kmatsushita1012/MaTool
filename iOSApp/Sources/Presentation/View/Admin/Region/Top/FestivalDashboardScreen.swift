//
//  FestivalDashboardView.swift
//  MaTool
//
//  Created by 松下和也 on 2025/05/09.
//

import ComposableArchitecture
import SwiftUI

@available(iOS 17.0, *)
struct FestivalDashboardScreen: View {
    @SwiftUI.Bindable var store: StoreOf<FestivalDashboardFeature>
    @Dependency(\.values.userGuideUrl) private var userGuideURLString
    @Dependency(\.values.contactURL) private var contactURLString

    private var userGuide: URL { URL(string: userGuideURLString)! }
    private var contact: URL { URL(string: contactURLString)! }

    var body: some View {
        WithPerceptionTracking {
            let contentState = FestivalDashboardContentState(
                title: "\(store.festival.name) \(store.festival.subname)",
                isAuthLoading: store.isAuthLoading,
                userGuide: userGuide,
                contact: contact,
                version: AppStatusClient.getCurrentVersion()
            )
            let actions = FestivalDashboardActions(
                onEdit: { store.send(.onEdit) },
                onPeriods: { store.send(.periodTapped) },
                onDistricts: { store.send(.districtsTapped) },
                onChangePassword: { store.send(.changePasswordTapped) },
                onUpdateEmail: { store.send(.updateEmailTapped) },
                onSignOut: { store.send(.signOutTapped) }
            )

            FestivalDashboardContentView(state: contentState, actions: actions)
            .fullScreenCover(
                item: $store.scope(state: \.editDestination, action: \.editDestination)
            ) { destination in
                switch destination.case {
                case .festival(let store):
                    FestivalEditScreen(store: store)
                }
            }
            .navigationDestination(item: $store.scope(state: \.destination, action: \.destination)) { destination in
                switch destination.case {
                case .districts(let store):
                    HeadquarterDistrictListScreen(store: store)
                case .periods(let store):
                    PeriodListScreen(store: store)
                case .changePassword(let store):
                    ChangePasswordScreen(store: store)
                case .updateEmail(let store):
                    UpdateEmailScreen(store: store)
                }
            }
            .alert($store.scope(state: \.alert, action: \.alert))
        }
    }
}
