import ComposableArchitecture
import Shared
import SwiftUI

struct StoreDashboardScreen: View {
    @SwiftUI.Bindable var store: StoreOf<StoreDashboardFeature>

    var body: some View {
        WithPerceptionTracking {
            StoreDashboardContentView(
                store: store.store,
                balance: store.balance,
                nextAction: store.nextAction,
                isBalanceLoading: store.isBalanceLoading,
                isPauseUpdating: store.isPauseUpdating,
                onNextActionTapped: { store.send(.nextActionTapped) },
                onBannerTapped: { store.send(.bannerTapped) },
                onInterstitialTapped: { store.send(.interstitialTapped) },
                onCreditTapped: { store.send(.creditTapped) },
                onEditTapped: { store.send(.editTapped) },
                onOwnerPausedChanged: { store.send(.ownerPausedChanged($0)) }
            )
            .modifier(StoreDashboardDestinations(store: store))
            .alert($store.scope(state: \.alert, action: \.alert))
            .task { store.send(.onAppear) }
        }
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
                ImageEditContentView(
                    store: imageStore,
                    onClose: {},
                    onSaveTapped: { store.send(.saveAdImagesTapped) },
                    isSaving: store.isAdImageSaving
                )
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
    let store: AdvertiserStore
    let balance: CreditAccount?
    let nextAction: StoreDashboardFeature.NextAction?
    let isBalanceLoading: Bool
    let isPauseUpdating: Bool
    let onNextActionTapped: () -> Void
    let onBannerTapped: () -> Void
    let onInterstitialTapped: () -> Void
    let onCreditTapped: () -> Void
    let onEditTapped: () -> Void
    let onOwnerPausedChanged: (Bool) -> Void

    private var deliveryStatus: String {
        if store.moderationStatus == .suspended { return "掲載停止中" }
        return store.ownerPaused ? "掲載停止中" : "公開中"
    }

    var body: some View {
        AdvertiserGroupedPage {
            Text(store.name)
                .font(.largeTitle)
                .foregroundStyle(Color(uiColor: .label))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 18)
                .padding(.top, 6)

            HStack {
                Text(deliveryStatus)
                    .font(.subheadline)
                    .foregroundStyle(Color(uiColor: .secondaryLabel))

                Spacer()

                if let balance {
                    Text("残高 \(balance.balance)pt")
                        .font(.subheadline)
                        .foregroundStyle(Color(uiColor: .secondaryLabel))
                } else if isBalanceLoading {
                    ProgressView()
                        .controlSize(.small)
                }
            }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 18)
                .padding(.top, 2)
                .padding(.bottom, 17)

            if let nextAction {
                Button(action: onNextActionTapped) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("次のステップ")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color(uiColor: .secondaryLabel))

                        HStack(spacing: 12) {
                            Text(nextAction.title)
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(Color(uiColor: .label))
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.right")
                                .font(.title3.weight(.light))
                                .foregroundStyle(Color(uiColor: .label))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(18)
                    .background(Color(uiColor: .secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 19, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(isPauseUpdating)
                .padding(.bottom, 25)
            }

            AdvertiserSection(title: "広告") {
                AdvertiserNavigationRow(
                    title: "バナー広告",
                    isEnabled: !isPauseUpdating,
                    action: onBannerTapped
                )
                AdvertiserRowSeparator()
                AdvertiserNavigationRow(
                    title: "全画面広告",
                    isEnabled: !isPauseUpdating,
                    action: onInterstitialTapped
                )
                AdvertiserRowSeparator()
                Toggle(
                    "広告配信を一時停止",
                    isOn: Binding(
                        get: { store.ownerPaused },
                        set: onOwnerPausedChanged
                    )
                )
                .tint(Color(uiColor: .systemGreen))
                .padding(.horizontal, 18)
                .frame(minHeight: 58)
                .disabled(isPauseUpdating)
            }

            AdvertiserSection(title: "クレジット") {
                if balance != nil {
                    AdvertiserNavigationRow(
                        title: "残高・購入",
                        isEnabled: !isBalanceLoading && !isPauseUpdating,
                        action: onCreditTapped
                    )
                } else if isBalanceLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: 54)
                } else {
                    AdvertiserNavigationRow(
                        title: "残高・購入",
                        isEnabled: !isPauseUpdating,
                        action: onCreditTapped
                    )
                }
            }

            AdvertiserSection(title: "店舗情報") {
                AdvertiserNavigationRow(
                    title: "基本情報を編集",
                    isEnabled: !isPauseUpdating,
                    action: onEditTapped
                )
            }
        }
        .navigationTitle("店舗ダッシュボード")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        StoreDashboardContentView(
            store: Store(
                id: "store",
                festivalId: "festival",
                ownerId: "owner",
                purchaseAccountToken: UUID(),
                name: "テスト店舗",
                businessHours: ""
            ),
            balance: CreditAccount(storeId: "store", balance: 0),
            nextAction: .banner,
            isBalanceLoading: false,
            isPauseUpdating: false,
            onNextActionTapped: {},
            onBannerTapped: {},
            onInterstitialTapped: {},
            onCreditTapped: {},
            onEditTapped: {},
            onOwnerPausedChanged: { _ in }
        )
    }
}
