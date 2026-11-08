import ComposableArchitecture
import Shared
import SwiftUI

struct PurchaseHistoryScreen: View {
    let store: StoreOf<PurchaseHistoryFeature>

    var body: some View {
        WithPerceptionTracking {
            PurchaseHistoryContentView(items: store.items)
        }
    }
}

struct PurchaseHistoryContentView: View {
    let items: [PurchaseHistoryItem]

    var body: some View {
        AdvertiserGroupedPage {
            AdvertiserSection(title: "購入履歴") {
                if items.isEmpty {
                    Text("購入履歴はありません")
                        .font(.subheadline)
                        .foregroundStyle(Color(uiColor: .secondaryLabel))
                        .frame(maxWidth: .infinity, minHeight: 54)
                        .padding(.horizontal, 18)
                } else {
                    ForEach(items) { item in
                        if items.first?.id != item.id {
                            AdvertiserRowSeparator()
                        }
                        HStack(alignment: .center, spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("広告クレジット")
                                    .font(.body)
                                    .foregroundStyle(Color(uiColor: .label))
                                Text(item.purchasedAt.formatted(date: .numeric, time: .shortened))
                                    .font(.caption)
                                    .foregroundStyle(Color(uiColor: .secondaryLabel))
                            }
                            Spacer(minLength: 8)
                            Text("+\(item.creditedAmount)pt")
                                .font(.subheadline)
                                .foregroundStyle(Color(uiColor: .secondaryLabel))
                        }
                        .frame(minHeight: 54)
                        .padding(.horizontal, 18)
                    }
                }
            }
        }
        .navigationTitle("購入履歴")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    PurchaseHistoryContentView(items: [])
}
