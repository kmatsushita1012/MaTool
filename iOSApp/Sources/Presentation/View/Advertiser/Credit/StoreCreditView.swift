import ComposableArchitecture
import Dependencies
import Shared
import SwiftUI

private let storeCreditTermsURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!

struct StoreCreditScreen: View {
    @SwiftUI.Bindable var store: StoreOf<StoreCreditFeature>
    @Dependency(\.values.contactURL) private var contactURLString

    var body: some View {
        StoreCreditContentView(
            balance: store.balance.balance,
            products: store.storeCreditCatalog.products,
            isCatalogLoading: store.storeCreditCatalog.isLoading,
            catalogErrorMessage: store.storeCreditCatalog.errorMessage,
            selectedProductID: store.selectedProduct?.id,
            purchasingProductID: store.purchasingProductID,
            isPurchasing: store.isPurchasing,
            isRestoring: store.isRestoring,
            visiblePurchaseHistory: store.visiblePurchaseHistory,
            isHistoryLoading: store.isHistoryLoading,
            hasMoreHistory: store.purchaseHistory.count > store.visiblePurchaseHistory.count,
            contactURL: URL(string: contactURLString),
            onProductSelected: { store.send(.productSelected($0)) },
            onPurchaseTapped: { store.send(.purchaseTapped($0)) },
            onRestoreTapped: { store.send(.restoreTapped) },
            onLoadMoreHistoryTapped: { store.send(.loadMoreHistoryTapped) }
        )
        .alert($store.scope(state: \.alert, action: \.alert))
        .task { store.send(.onAppear) }
    }
}

struct StoreCreditContentView: View {
    let balance: Int
    let products: [StoreCreditProduct]
    let isCatalogLoading: Bool
    let catalogErrorMessage: String?
    let selectedProductID: String?
    let purchasingProductID: String?
    let isPurchasing: Bool
    let isRestoring: Bool
    let visiblePurchaseHistory: [PurchaseHistoryItem]
    let isHistoryLoading: Bool
    let hasMoreHistory: Bool
    let contactURL: URL?
    let onProductSelected: (String) -> Void
    let onPurchaseTapped: (String) -> Void
    let onRestoreTapped: () -> Void
    let onLoadMoreHistoryTapped: () -> Void

    private var isBusy: Bool {
        isPurchasing || isRestoring
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                StoreCreditBalanceSection(balance: balance)

                StoreCreditProductSection(
                    products: products,
                    isLoading: isCatalogLoading,
                    errorMessage: catalogErrorMessage,
                    selectedProductID: selectedProductID,
                    purchasingProductID: purchasingProductID,
                    isBusy: isBusy,
                    onProductSelected: onProductSelected,
                    onPurchaseTapped: onPurchaseTapped
                )

                StoreCreditActionsGroup(
                    isRestoring: isRestoring,
                    isBusy: isBusy,
                    contactURL: contactURL,
                    onRestoreTapped: onRestoreTapped
                )

                StoreCreditHistorySection(
                    items: visiblePurchaseHistory,
                    isLoading: isHistoryLoading,
                    hasMoreItems: hasMoreHistory,
                    isBusy: isBusy,
                    onLoadMoreTapped: onLoadMoreHistoryTapped
                )
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollIndicators(.hidden)
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("クレジット")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct StoreCreditBalanceSection: View {
    let balance: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("利用可能ポイント")
                .font(.headline)
                .foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(balance.formatted())
                    .font(.largeTitle.weight(.bold))
                Text("pt")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct StoreCreditProductSection: View {
    let products: [StoreCreditProduct]
    let isLoading: Bool
    let errorMessage: String?
    let selectedProductID: String?
    let purchasingProductID: String?
    let isBusy: Bool
    let onProductSelected: (String) -> Void
    let onPurchaseTapped: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ポイントを購入")
                .font(.headline)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16)

            if isLoading && products.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity)
            } else if products.isEmpty {
                if let errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.secondary)
                }
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(products) { product in
                            StoreCreditProductCard(
                                product: product,
                                isSelected: selectedProductID == product.id,
                                isPurchasing: purchasingProductID == product.id,
                                isDisabled: isBusy,
                                termsURL: storeCreditTermsURL,
                                onSelect: { onProductSelected(product.id) },
                                onPurchaseTap: { onPurchaseTapped(product.id) }
                            )
                        }
                    }
                }
                .scrollClipDisabled()
            }
        }
    }
}

private struct StoreCreditActionsGroup: View {
    let isRestoring: Bool
    let isBusy: Bool
    let contactURL: URL?
    let onRestoreTapped: () -> Void

    var body: some View {
        GroupedSurface {
            VStack(spacing: 0) {
                Button(action: onRestoreTapped) {
                    Text("購入を復元")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.accentColor)
                .loadingIndicator(isLoading: isRestoring)
                .disabled(isBusy)
                .padding(16)

                if let contactURL {
                    Divider()
                        .padding(.horizontal, 16)

                    Link(destination: contactURL) {
                        Label("お問い合わせ", systemImage: "envelope")
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                    .foregroundStyle(Color.accentColor)
                    .disabled(isBusy)
                    .padding(16)
                }
            }
        }
    }
}

private struct StoreCreditHistorySection: View {
    let items: [PurchaseHistoryItem]
    let isLoading: Bool
    let hasMoreItems: Bool
    let isBusy: Bool
    let onLoadMoreTapped: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("購入履歴")
                .font(.headline)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16)

            if isLoading && items.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity)
            } else if items.isEmpty {
                GroupedSurface {
                    Text("購入履歴はありません")
                        .foregroundStyle(.secondary)
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                GroupedSurface {
                    VStack(spacing: 0) {
                        ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                            LabeledContent {
                                Text("+\(item.creditedAmount)pt")
                                    .font(.body.weight(.semibold))
                            } label: {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("広告クレジット")
                                    Text(item.purchasedAt.formatted(date: .numeric, time: .shortened))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.vertical, 16)

                            if index < items.count - 1 || hasMoreItems {
                                Divider()
                            }
                        }

                        if hasMoreItems {
                            Button("さらに読み込む", action: onLoadMoreTapped)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 16)
                                .disabled(isBusy)
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
        }
    }
}
