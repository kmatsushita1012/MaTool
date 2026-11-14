import ComposableArchitecture
import Shared
import SwiftUI

struct StoreDashboardScreen: View {
    @SwiftUI.Bindable var store: StoreOf<StoreDashboardFeature>

    var body: some View {
        StoreDashboardContentView(
            storeName: store.store.name,
            deliveryStatus: deliveryStatus,
            creditBalance: store.balance?.balance,
            isBalanceLoading: store.isBalanceLoading,
            showsNextStepLabel: store.hasPurchasedCredits == false,
            navigationSubtitle: navigationSubtitle,
            isOwnerPaused: Binding(
                get: { store.store.ownerPaused },
                set: { store.send(.ownerPausedChanged($0)) }
            ),
            isPauseUpdating: store.isPauseUpdating,
            onBannerTapped: { store.send(.bannerTapped) },
            onInterstitialTapped: { store.send(.interstitialTapped) },
            onCreditTapped: { store.send(.creditTapped) },
            onEditTapped: { store.send(.editTapped) }
        )
        .modifier(StoreDashboardDestinations(store: store))
        .alert($store.scope(state: \.alert, action: \.alert))
        .task { store.send(.onAppear) }
    }

    private var deliveryStatus: String {
        if store.store.moderationStatus == .suspended { return "掲載停止中" }
        return store.store.ownerPaused ? "掲載停止中" : "公開中"
    }

    private var navigationSubtitle: String {
        guard let balance = store.balance?.balance else { return deliveryStatus }
        return "\(deliveryStatus)・\(balance)pt"
    }
}

private struct StoreDashboardDestinations: ViewModifier {
    @SwiftUI.Bindable var store: StoreOf<StoreDashboardFeature>

    func body(content: Content) -> some View {
        content
            .navigationDestination(item: $store.scope(
                state: \.destination?.storeEdit,
                action: \.destination.storeEdit
            )) { editStore in
                StoreEditScreen(store: editStore)
            }
            .navigationDestination(item: $store.scope(
                state: \.destination?.storeAdImage,
                action: \.destination.storeAdImage
            )) { imageStore in
                ImageEditScreen(store: imageStore)
            }
            .navigationDestination(item: $store.scope(
                state: \.destination?.credit,
                action: \.destination.credit
            )) { creditStore in
                StoreCreditScreen(store: creditStore)
            }
    }
}

struct StoreDashboardContentView: View {
    let storeName: String
    let deliveryStatus: String
    let creditBalance: Int?
    let isBalanceLoading: Bool
    let showsNextStepLabel: Bool
    let navigationSubtitle: String
    @Binding var isOwnerPaused: Bool
    let isPauseUpdating: Bool
    let onBannerTapped: () -> Void
    let onInterstitialTapped: () -> Void
    let onCreditTapped: () -> Void
    let onEditTapped: () -> Void

    var body: some View {
        Form {
            Section {
                StoreDashboardNextStepButton(
                    creditBalance: creditBalance,
                    showsNextStepLabel: showsNextStepLabel,
                    action: onCreditTapped
                )
                    .disabled(isBalanceLoading || isPauseUpdating || creditBalance == nil)
                    .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }

            if #unavailable(iOS 26.0) {
                Section("配信状況") {
                    LabeledContent("配信状態", value: deliveryStatus)
                }
            }

            Section("広告") {
                NavigationItemView(title: "バナー広告", onTap: onBannerTapped)
                    .disabled(isPauseUpdating)
                NavigationItemView(title: "全画面広告", onTap: onInterstitialTapped)
                    .disabled(isPauseUpdating)
                Toggle("広告配信を一時停止", isOn: $isOwnerPaused)
                    .disabled(isPauseUpdating)
            }

            Section("ポイント残高") {
                NavigationItemView(
                    title: "残高・購入",
                    status: creditBalance.map { "\($0)pt" },
                    onTap: onCreditTapped
                )
                .disabled(isBalanceLoading || isPauseUpdating || creditBalance == nil)
            }

            Section("店舗情報") {
                NavigationItemView(title: "基本情報を編集", onTap: onEditTapped)
                    .disabled(isPauseUpdating)
            }
        }
        .navigationTitle(storeName)
        .navigationBarTitleDisplayMode(.large)
        .modifier(StoreDashboardSubtitle(subtitle: navigationSubtitle))
    }
}

private struct StoreDashboardNextStepButton: View {
    let creditBalance: Int?
    let showsNextStepLabel: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    if showsNextStepLabel {
                        Text("次のステップ")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Text("クレジットを購入")
                        .font(.headline)
                        .foregroundStyle(.primary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(creditBalance.map { $0.formatted() } ?? "—")
                        .font(.largeTitle.weight(.bold))
                        .foregroundStyle(creditBalance == nil ? .secondary : .primary)

                    Text("pt")
                        .font(.title3)
                        .foregroundStyle(.secondary)

                    Image(systemName: "chevron.right")
                        .font(.headline)
                        .foregroundStyle(Color.accentColor)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(.tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

private struct StoreDashboardSubtitle: ViewModifier {
    let subtitle: String

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.navigationSubtitle(Text(verbatim: subtitle))
        } else {
            content
        }
    }
}

#Preview {
    NavigationStack {
        StoreDashboardContentView(
            storeName: "テスト店舗",
            deliveryStatus: "公開中",
            creditBalance: 0,
            isBalanceLoading: false,
            showsNextStepLabel: true,
            navigationSubtitle: "公開中・0pt",
            isOwnerPaused: .constant(false),
            isPauseUpdating: false,
            onBannerTapped: {},
            onInterstitialTapped: {},
            onCreditTapped: {},
            onEditTapped: {}
        )
    }
}
