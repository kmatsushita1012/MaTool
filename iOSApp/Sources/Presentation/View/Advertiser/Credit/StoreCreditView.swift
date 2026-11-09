import ComposableArchitecture
import Dependencies
import Shared
import SwiftUI

private let storeCreditTermsURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!

struct StoreCreditScreen: View {
    @SwiftUI.Bindable var store: StoreOf<StoreCreditFeature>
    @Dependency(\.values.contactURL) private var contactURLString

    private var isBusy: Bool {
        store.isPurchasing || store.isRestoring
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                balanceSection
                productSection
                purchaseActions
                purchaseHistorySection
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollIndicators(.hidden)
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("クレジット")
        .navigationBarTitleDisplayMode(.inline)
        .alert($store.scope(state: \.alert, action: \.alert))
        .task { store.send(.onAppear) }
    }

    private var balanceSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("利用可能ポイント")
                .font(.headline)
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(store.balance.balance.formatted())
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

    private var productSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("ポイントを購入")
                .font(.headline)

            if store.storeCreditCatalog.isLoading && store.storeCreditCatalog.products.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity)
            } else if store.storeCreditCatalog.products.isEmpty {
                if let errorMessage = store.storeCreditCatalog.errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.secondary)
                }
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(store.storeCreditCatalog.products) { product in
                            productCard(product)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 4)
                }
                .padding(.horizontal, -16)
                .scrollClipDisabled()

                if let product = store.selectedProduct {
                    Text(product.description)
                        .fixedSize(horizontal: false, vertical: true)
                    Link("利用規約", destination: storeCreditTermsURL)
                        .font(.footnote)
                        .underline()
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func productCard(_ product: StoreCreditProduct) -> some View {
        let isSelected = store.selectedProduct?.id == product.id
        return Button {
            store.send(.productSelected(product.id))
        } label: {
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 16) {
                    Text(product.displayName)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(product.displayPrice)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.primary)
                }
                Spacer(minLength: 0)
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
            }
            .padding(16)
            .frame(width: 244, alignment: .leading)
            .background(
                Color(uiColor: .secondarySystemGroupedBackground),
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
            .overlay {
                if isSelected {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Color.accentColor, lineWidth: 2)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(isBusy)
    }

    private var purchaseActions: some View {
        VStack(spacing: 16) {
            Button {
                store.send(.purchaseTapped)
            } label: {
                Text(store.isPurchasing ? "購入処理中" : "購入する")
                    .frame(maxWidth: .infinity)
                    .overlay(alignment: .trailing) {
                        if store.isPurchasing {
                            ProgressView()
                                .tint(.white)
                                .padding(.trailing, 16)
                        }
                    }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(isBusy || store.selectedProduct == nil)

            Button {
                store.send(.restoreTapped)
            } label: {
                Text("購入を復元")
                    .frame(maxWidth: .infinity)
                    .overlay(alignment: .trailing) {
                        if store.isRestoring {
                            ProgressView()
                                .controlSize(.small)
                                .padding(.trailing, 16)
                        }
                    }
            }
            .buttonStyle(.bordered)
            .disabled(isBusy)

            if let contactURL = URL(string: contactURLString) {
                Link(destination: contactURL) {
                    Label("お問い合わせ", systemImage: "envelope")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(isBusy)
            }
        }
    }

    private var purchaseHistorySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("購入履歴")
                .font(.headline)

            if store.isHistoryLoading && store.purchaseHistory.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity)
            } else if store.purchaseHistory.isEmpty {
                ContentUnavailableView("購入履歴はありません", systemImage: "receipt")
                    .frame(maxWidth: .infinity)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(store.visiblePurchaseHistory.enumerated()), id: \.element.id) { index, item in
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("広告クレジット")
                                Text(item.purchasedAt.formatted(date: .numeric, time: .shortened))
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text("+\(item.creditedAmount)pt")
                                .font(.body.weight(.semibold))
                        }
                        .padding(.vertical, 16)

                        if index < store.visiblePurchaseHistory.count - 1 {
                            Divider()
                        }
                    }
                }
                .padding(.horizontal, 16)
                .background(
                    Color(uiColor: .secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                )

                if store.purchaseHistory.count > store.visiblePurchaseHistory.count {
                    Button("さらに読み込む") {
                        store.send(.loadMoreHistoryTapped)
                    }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)
                    .disabled(isBusy)
                }
            }
        }
    }
}
