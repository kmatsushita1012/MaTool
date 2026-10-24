//
//  FestivalDashboardView.swift
//  MaTool
//
//  Created by 松下和也 on 2025/05/09.
//

import ComposableArchitecture
import NavigationSwipeControl
import SwiftUI

@available(iOS 17.0, *)
struct FestivalDashboardScreen: View {
    @SwiftUI.Bindable var store: StoreOf<FestivalDashboardFeature>

    var body: some View {
        WithPerceptionTracking {
            FestivalDashboardContentView(
                festivalTitle: festivalTitle,
                onEditTapped: { store.send(.onEdit) },
                onPeriodsTapped: { store.send(.periodTapped) },
                onDistrictsTapped: { store.send(.districtsTapped) },
                onChangePasswordTapped: { store.send(.changePasswordTapped) },
                onUpdateEmailTapped: { store.send(.updateEmailTapped) },
                onSignOutTapped: { store.send(.signOutTapped) },
                onSettingsTapped: { store.send(.settingsTapped) }
            )
            .modifier(FestivalDashboardDestinations(store: store))
            .alert($store.scope(state: \.alert, action: \.alert))
            .loadingOverlay(store.isLoading)
        }
    }

    private var festivalTitle: String {
        "\(store.festival.name) \(store.festival.subname)"
    }
}

@available(iOS 17.0, *)
private struct FestivalDashboardDestinations: ViewModifier {
    @SwiftUI.Bindable var store: StoreOf<FestivalDashboardFeature>

    func body(content: Content) -> some View {
        content
            .navigationDestination(item: $store.scope(state: \.destination?.edit, action: \.destination.edit)) { store in
                FestivalEditView(store: store)
            }
            .navigationDestination(item: $store.scope(state: \.destination?.districts, action: \.destination.districts)) { store in
                HeadquarterDistrictListView(store: store)
            }
            .navigationDestination(item: $store.scope(state: \.destination?.periods, action: \.destination.periods)) { store in
                PeriodListView(store: store)
            }
            .navigationDestination(item: $store.scope(state: \.destination?.changePassword, action: \.destination.changePassword)) { store in
                ChangePasswordView(store: store)
            }
            .navigationDestination(item: $store.scope(state: \.destination?.updateEmail, action: \.destination.updateEmail)) { store in
                UpdateEmailView(store: store)
            }
            .navigationDestination(item: $store.scope(state: \.destination?.settings, action: \.destination.settings)) { store in
                SettingsView(store: store)
            }
    }
}

@available(iOS 17.0, *)
typealias FestivalDashboardView = FestivalDashboardScreen

@available(iOS 17.0, *)
struct FestivalDashboardContentView: View {
    let festivalTitle: String
    let onEditTapped: () -> Void
    let onPeriodsTapped: () -> Void
    let onDistrictsTapped: () -> Void
    let onChangePasswordTapped: () -> Void
    let onUpdateEmailTapped: () -> Void
    let onSignOutTapped: () -> Void
    let onSettingsTapped: () -> Void

    var body: some View {
        List {
            Section {
                NavigationItemView(
                    title: "祭典情報",
                    iconName: "info.circle",
                    onTap: onEditTapped
                )
                NavigationItemView(
                    title: "日程",
                    iconName: "calendar",
                    onTap: onPeriodsTapped
                )
            }

            Section {
                NavigationItemView(
                    title: "参加町一覧",
                    iconName: "list.bullet",
                    onTap: onDistrictsTapped
                )
            }

            Section {
                Button("パスワード変更", action: onChangePasswordTapped)
                Button("メールアドレス変更", action: onUpdateEmailTapped)
            }
            Section {
                Button("ログアウト", action: onSignOutTapped)
                    .foregroundColor(.red)
            }
        }
        .navigationTitle(festivalTitle)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("設定", systemImage: "gearshape", action: onSettingsTapped)
            }
        }
    }
}

#Preview {
    FestivalDashboardContentView(
        festivalTitle: "",
        onEditTapped: {},
        onPeriodsTapped: {},
        onDistrictsTapped: {},
        onChangePasswordTapped: {},
        onUpdateEmailTapped: {},
        onSignOutTapped: {},
        onSettingsTapped: {}
    )
}
