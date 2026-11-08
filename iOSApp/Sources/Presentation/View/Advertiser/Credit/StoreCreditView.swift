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
        Form {
            Section("残高") {
                if let balance {
                    LabeledContent("利用可能", value: "\(balance.balance)pt")
                } else if isLoading {
                    ProgressView()
                }
            }

            Section("クレジット購入") {
                if products.isEmpty {
                    if let productErrorMessage {
                        Text(productErrorMessage)
                            .foregroundStyle(.secondary)
                    } else if isLoading {
                        ProgressView()
                    }
                }
                ForEach(products) { product in
                    Button { onPurchaseTapped(product.id) } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            LabeledContent(product.displayName, value: product.displayPrice)
                            if !product.description.isEmpty {
                                Text(product.description)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .disabled(isPurchasing || isLoading)
                }
                if isPurchasing {
                    ProgressView("購入を処理中")
                }
            }

            Section("購入情報") {
                Button("購入履歴", action: onHistoryTapped)
                    .disabled(isHistoryLoading)
                    .loadingIndicator(isLoading: isHistoryLoading)
            }

            Section {
                Text("バナー表示：1pt消費")
                    .foregroundStyle(.secondary)
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
