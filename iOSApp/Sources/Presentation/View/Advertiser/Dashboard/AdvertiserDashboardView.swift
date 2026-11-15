import ComposableArchitecture
import SwiftUI

struct AdvertiserDashboardScreen: View {
    @SwiftUI.Bindable var store: StoreOf<AdvertiserDashboardFeature>

    var body: some View {
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

private struct AdvertiserDashboardDestinations: ViewModifier {
    @SwiftUI.Bindable var store: StoreOf<AdvertiserDashboardFeature>

    func body(content: Content) -> some View {
        content
            .navigationDestination(item: $store.scope(
                state: \.destination?.storeCreate,
                action: \.destination.storeCreate
            )) { createStore in
                StoreEditScreen(store: createStore)
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
        List {
            Section("所有店舗") {
                if isLoading && stores.isEmpty {
                    ProgressView()
                } else if stores.isEmpty {
                    Text("店舗がありません")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(stores) { store in
                        NavigationItemView(
                            title: store.name,
                            status: statusText(for: store),
                            onTap: { onStoreTapped(store) }
                        )
                        .disabled(isNavigationDisabled)
                    }
                }

                Button("店舗を追加", systemImage: "plus", action: onAddStoreTapped)
                .disabled(isNavigationDisabled)
            }

            Section("アカウント") {
                Button("パスワード変更", action: onChangePasswordTapped)
                    .disabled(isNavigationDisabled)
                Button("メールアドレス変更", action: onUpdateEmailTapped)
                    .disabled(isNavigationDisabled)
                Button("ログアウト", action: onSignOutTapped)
                    .foregroundStyle(.red)
                    .loadingIndicator(isLoading: isSigningOut)
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
