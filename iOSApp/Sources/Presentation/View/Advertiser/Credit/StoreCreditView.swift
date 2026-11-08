import ComposableArchitecture
import Shared
import SwiftUI

struct StoreCreditScreen: View {
    @SwiftUI.Bindable var store: StoreOf<StoreCreditFeature>

    var body: some View {
        WithPerceptionTracking {
            StoreCreditContentView(
                balance: store.balance,
                products: store.products,
                productErrorMessage: store.productErrorMessage,
                isLoading: store.isLoading,
                isPurchasing: store.isPurchasing,
                isHistoryLoading: store.isHistoryLoading,
                onPurchaseTapped: { store.send(.purchaseTapped($0)) },
                onHistoryTapped: { store.send(.historyTapped) }
            )
            .navigationDestination(
                item: $store.scope(state: \.destination?.history, action: \.destination.history)
            ) { historyStore in
                PurchaseHistoryScreen(store: historyStore)
            }
            .alert($store.scope(state: \.alert, action: \.alert))
            .task { store.send(.onAppear) }
        }
    }
}

struct StoreCreditContentView: View {
    let balance: CreditAccount?
    let products: [StoreCreditProduct]
    let productErrorMessage: String?
    let isLoading: Bool
    let isPurchasing: Bool
    let isHistoryLoading: Bool
    let onPurchaseTapped: (String) -> Void
    let onHistoryTapped: () -> Void

    var body: some View {
        AdvertiserGroupedPage {
            AdvertiserSection(title: "残高") {
                if let balance {
                    HStack {
                        Text("利用可能")
                            .font(.subheadline)
                        Spacer()
                        Text("\(balance.balance)pt")
                            .font(.system(size: 20, weight: .semibold))
                    }
                    .frame(minHeight: 66)
                    .padding(.horizontal, 18)
                } else if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: 66)
                }
            }

            AdvertiserSection(title: "クレジット購入") {
                if products.isEmpty {
                    if let productErrorMessage {
                        Text(productErrorMessage)
                            .font(.subheadline)
                            .foregroundStyle(Color(uiColor: .secondaryLabel))
                            .padding(18)
                    } else if isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity, minHeight: 54)
                    }
                }
                ForEach(products.indices, id: \.self) { index in
                    if index > 0 || productErrorMessage != nil {
                        AdvertiserRowSeparator()
                    }
                    AdvertiserNavigationRow(
                        title: products[index].displayName,
                        value: products[index].displayPrice,
                        isEnabled: !isPurchasing && !isLoading,
                        action: { onPurchaseTapped(products[index].id) }
                    )
                }
                if isPurchasing {
                    AdvertiserRowSeparator()
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: 54)
                }
            }

            AdvertiserSection(title: "購入情報") {
                AdvertiserNavigationRow(
                    title: "購入履歴",
                    isEnabled: !isHistoryLoading,
                    action: onHistoryTapped
                )
                if isHistoryLoading {
                    AdvertiserRowSeparator()
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: 54)
                }
            }
        }
        .navigationTitle("クレジット")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        StoreCreditContentView(
            balance: nil,
            products: [],
            productErrorMessage: nil,
            isLoading: false,
            isPurchasing: false,
            isHistoryLoading: false,
            onPurchaseTapped: { _ in },
            onHistoryTapped: {}
        )
    }
}
