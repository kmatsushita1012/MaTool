import ComposableArchitecture
import Shared

@Reducer
struct PurchaseHistoryFeature {
    @ObservableState
    struct State: Equatable {
        let items: [PurchaseHistoryItem]

        init(items: [PurchaseHistoryItem]) {
            self.items = items
        }
    }

    enum Action: Equatable {}

    var body: some ReducerOf<Self> {
        EmptyReducer()
    }
}
