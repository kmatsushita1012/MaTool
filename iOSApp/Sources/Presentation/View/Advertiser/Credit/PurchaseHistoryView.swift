import ComposableArchitecture
import Shared
import SwiftUI

struct PurchaseHistoryScreen: View {
    let store: StoreOf<PurchaseHistoryFeature>

    var body: some View {
        PurchaseHistoryContentView(items: store.items)
    }
}

struct PurchaseHistoryContentView: View {
    let items: [PurchaseHistoryItem]

    var body: some View {
        List {
            Section("購入履歴") {
                if items.isEmpty {
                    ContentUnavailableView("購入履歴はありません", systemImage: "receipt")
                } else {
                    ForEach(items) { item in
                        LabeledContent {
                            Text("+\(item.creditedAmount)pt")
                        } label: {
                            VStack(alignment: .leading) {
                                Text("広告クレジット")
                                Text(item.purchasedAt.formatted(date: .numeric, time: .shortened))
                                    .foregroundStyle(.secondary)
                            }
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
    NavigationStack {
        PurchaseHistoryContentView(items: [])
    }
}
