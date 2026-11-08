import ComposableArchitecture
import SwiftUI

struct AdvertiserDashboardScreen: View {
    @SwiftUI.Bindable var store: StoreOf<AdvertiserDashboardFeature>

    var body: some View {
        WithPerceptionTracking {
            AdvertiserDashboardContentView(
                stores: store.stores,
                isLoading: store.isLoading,
                isSigningOut: store.isSigningOut,
                isSettingsLoading: store.isSettingsLoading,
                onStoreTapped: { store.send(.storeTapped($0)) },
                onAddStoreTapped: { store.send(.addStoreTapped) },
                onChangePasswordTapped: { store.send(.changePasswordTapped) },
                onUpdateEmailTapped: { store.send(.updateEmailTapped) },
                onSettingsTapped: { store.send(.settingsTapped) },
                onSignOutTapped: { store.send(.signOutTapped) }
            )
            .modifier(AdvertiserDashboardDestinations(store: store))
            .alert($store.scope(state: \.alert, action: \.alert))
            .task { store.send(.onAppear) }
        }
    }
}

private struct AdvertiserDashboardDestinations: ViewModifier {
    @SwiftUI.Bindable var store: StoreOf<AdvertiserDashboardFeature>

    func body(content: Content) -> some View {
        content
            .navigationDestination(item: $store.scope(
                state: \.destination?.storeCreate,
                action: \.destination.storeCreate
            )) { store in
                StoreEditScreen(store: store)
            }
            .navigationDestination(item: $store.scope(
                state: \.destination?.storeDashboard,
                action: \.destination.storeDashboard
            )) { store in
                StoreDashboardScreen(store: store)
            }
            .navigationDestination(item: $store.scope(
                state: \.destination?.changePassword,
                action: \.destination.changePassword
            )) { store in
                ChangePasswordView(store: store)
            }
            .navigationDestination(item: $store.scope(
                state: \.destination?.updateEmail,
                action: \.destination.updateEmail
            )) { store in
                UpdateEmailView(store: store)
            }
            .navigationDestination(item: $store.scope(
                state: \.destination?.settings,
                action: \.destination.settings
            )) { store in
                SettingsView(store: store)
            }
    }
}

struct AdvertiserDashboardContentView: View {
    let stores: [AdvertiserStore]
    let isLoading: Bool
    let isSigningOut: Bool
    let isSettingsLoading: Bool
    let onStoreTapped: (AdvertiserStore) -> Void
    let onAddStoreTapped: () -> Void
    let onChangePasswordTapped: () -> Void
    let onUpdateEmailTapped: () -> Void
    let onSettingsTapped: () -> Void
    let onSignOutTapped: () -> Void

    private var isNavigationDisabled: Bool {
        isLoading || isSigningOut || isSettingsLoading
    }

    var body: some View {
        AdvertiserGroupedPage {
            AdvertiserSection(title: "所有店舗") {
                if isLoading && stores.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: 54)
                } else if stores.isEmpty {
                    Text("店舗がありません")
                        .foregroundStyle(Color(uiColor: .secondaryLabel))
                        .frame(maxWidth: .infinity, minHeight: 54)
                        .padding(.horizontal, 18)
                } else {
                    ForEach(stores.indices, id: \.self) { index in
                        if index > 0 {
                            AdvertiserRowSeparator()
                        }
                        AdvertiserNavigationRow(
                            title: stores[index].name,
                            subtitle: statusText(for: stores[index]),
                            action: { onStoreTapped(stores[index]) }
                        )
                    }
                }

                AdvertiserRowSeparator()
                AdvertiserNavigationRow(
                    title: "店舗を追加",
                    systemImage: "plus",
                    isEnabled: !isNavigationDisabled,
                    action: onAddStoreTapped
                )
            }

            AdvertiserSection(title: "アカウント") {
                AdvertiserNavigationRow(
                    title: "パスワード変更",
                    isEnabled: !isNavigationDisabled,
                    action: onChangePasswordTapped
                )
                AdvertiserRowSeparator()
                AdvertiserNavigationRow(
                    title: "メールアドレス変更",
                    isEnabled: !isNavigationDisabled,
                    action: onUpdateEmailTapped
                )
                AdvertiserRowSeparator()
                AdvertiserNavigationRow(
                    title: isSigningOut ? "ログアウト中" : "ログアウト",
                    isDestructive: true,
                    isEnabled: !isSigningOut,
                    action: onSignOutTapped
                )
            }
        }
        .navigationTitle("店舗管理")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("設定", systemImage: "gearshape", action: onSettingsTapped)
                    .disabled(isNavigationDisabled)
            }
        }
    }

    private func statusText(for store: AdvertiserStore) -> String {
        if store.moderationStatus == .suspended { return "掲載停止中" }
        return store.ownerPaused ? "掲載停止中" : "公開中"
    }
}

#Preview {
    NavigationStack {
        AdvertiserDashboardContentView(
            stores: [],
            isLoading: false,
            isSigningOut: false,
            isSettingsLoading: false,
            onStoreTapped: { _ in },
            onAddStoreTapped: {},
            onChangePasswordTapped: {},
            onUpdateEmailTapped: {},
            onSettingsTapped: {},
            onSignOutTapped: {}
        )
    }
}
