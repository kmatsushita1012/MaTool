import SwiftUI

struct StoreCreditProductCard: View {
    let product: StoreCreditProduct
    let isSelected: Bool
    let isPurchasing: Bool
    let isDisabled: Bool
    let termsURL: URL
    let onSelect: () -> Void
    let onPurchaseTap: () -> Void

    var body: some View {
        GroupedSurface {
            VStack(alignment: .leading, spacing: 16) {
                Button(action: onSelect) {
                    VStack(alignment: .leading, spacing: 16) {
                        Text(product.displayName)
                            .font(.headline)
                            .foregroundStyle(.secondary)

                        Text(product.description)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)

                        Spacer(minLength: 0)

                        Text(product.displayPrice)
                            .font(.title3.weight(.bold))
                            .foregroundStyle(.primary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if isSelected {
                    purchaseButton
                        .buttonStyle(.borderedProminent)
                } else {
                    purchaseButton
                        .buttonStyle(.bordered)
                }

                Link("利用規約", destination: termsURL)
                    .font(.caption)
                    .underline()
                    .lineLimit(1)
                    .foregroundStyle(.secondary)
            }
            .padding(16)
            .frame(width: 248, alignment: .leading)
            .frame(maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(maxHeight: .infinity, alignment: .topLeading)
        .overlay {
            if isSelected {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.accentColor.opacity(0.55), lineWidth: 2)
            }
        }
    }

    private var purchaseButton: some View {
        Button(action: onPurchaseTap) {
            Text("購入する")
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .controlSize(.large)
        .tint(.accentColor)
        .loadingIndicator(isLoading: isPurchasing)
        .disabled(isDisabled)
    }
}
