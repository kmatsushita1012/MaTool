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
        List {
            if items.isEmpty {
                ContentUnavailableView("購入履歴がありません", systemImage: "clock.arrow.circlepath")
            } else {
                ForEach(items) { item in
                    LabeledContent {
                        Text("\(item.creditedAmount)pt")
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.purchasedAt.formatted(date: .numeric, time: .shortened))
                            Text(item.productId)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
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
