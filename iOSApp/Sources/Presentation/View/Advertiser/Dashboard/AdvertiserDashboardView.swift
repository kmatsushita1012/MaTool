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
                onStoreTapped: { store.send(.storeTapped($0)) },
                onAddStoreTapped: { store.send(.addStoreTapped) },
                onSignOutTapped: { store.send(.signOutTapped) }
            )
            .navigationDestination(
                item: $store.scope(state: \.destination?.storeEdit, action: \.destination.storeEdit)
            ) { store in
                StoreEditScreen(store: store)
            }
            .navigationBarBackButtonHidden(store.isRootDestination)
            .alert($store.scope(state: \.alert, action: \.alert))
            .task { store.send(.onAppear) }
        }
    }
}

struct AdvertiserDashboardContentView: View {
    let stores: [AdvertiserStore]
    let isLoading: Bool
    let isSigningOut: Bool
    let onStoreTapped: (AdvertiserStore) -> Void
    let onAddStoreTapped: () -> Void
    let onSignOutTapped: () -> Void

    var body: some View {
        List {
            Section("所有店舗") {
                if isLoading && stores.isEmpty {
                    ProgressView()
                } else if stores.isEmpty {
                    ContentUnavailableView("店舗がありません", systemImage: "storefront")
                } else {
                    ForEach(stores) { item in
                        Button { onStoreTapped(item) } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(item.name)
                                        .foregroundStyle(.primary)
                                Text(statusText(for: item))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.tertiary)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }

                Button("店舗を追加", systemImage: "plus", action: onAddStoreTapped)
                    .disabled(isLoading)
            }

            Section("アカウント") {
                Button("ログアウト", role: .destructive, action: onSignOutTapped)
                    .loadingIndicator(isLoading: isSigningOut)
            }
        }
        .navigationTitle("店舗管理")
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
            onStoreTapped: { _ in },
            onAddStoreTapped: {},
            onSignOutTapped: {}
        )
    }
}
