import ComposableArchitecture
import Shared

@Reducer
struct StoreCreditFeature {
    @Reducer
    enum Destination {
        case history(PurchaseHistoryFeature)
    }

    @ObservableState
    struct State: Equatable {
        let store: AdvertiserStore
        var balance: CreditAccount?
        var products: [StoreCreditProduct] = []
        var productErrorMessage: String?
        var isLoading = false
        var isPurchasing = false
        var purchasingProductID: String?
        var isHistoryLoading = false
        @Presents var destination: Destination.State?
        @Presents var alert: AlertFeature.State?

        init(store: AdvertiserStore) {
            self.store = store
        }
    }

    @CasePathable
    enum Action: Equatable {
        case onAppear
        case loadReceived(AppResult<StoreCreditPreparation>)
        case purchaseTapped(String)
        case purchaseReceived(AppResult<StoreCreditPurchaseCompletion>)
        case historyTapped
        case historyReceived(AppResult<[PurchaseHistoryItem]>)
        case destination(PresentationAction<Destination.Action>)
        case alert(PresentationAction<AlertFeature.Action>)
    }

    @Dependency(\.storeCreditUsecase) private var storeCreditUsecase

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                guard !state.isLoading else { return .none }
                state.isLoading = true
                let store = state.store
                return .task(Action.loadReceived) {
                    await storeCreditUsecase.recoverUnfinishedPurchases(for: [store])
                    let balance = try await storeCreditUsecase.loadBalance(storeId: store.id)
                    let products: [StoreCreditProduct]
                    let productErrorMessage: String?
                    do {
                        products = try await storeCreditUsecase.loadProducts()
                        productErrorMessage = products.isEmpty ? "購入できる商品がありません。" : nil
                    } catch {
                        products = []
                        productErrorMessage = error.localizedDescription
                    }
                    return StoreCreditPreparation(
                        balance: balance,
                        products: products,
                        productErrorMessage: productErrorMessage
                    )
                }

            case .loadReceived(.success(let preparation)):
                state.isLoading = false
                state.balance = preparation.balance
                state.products = preparation.products
                state.productErrorMessage = preparation.productErrorMessage
                return .none

            case .loadReceived(.failure(let error)):
                state.isLoading = false
                state.alert = .error("クレジット残高を取得できませんでした。\n\(error.message)")
                return .none

            case .purchaseTapped(let productId):
                guard !state.isPurchasing else { return .none }
                state.isPurchasing = true
                state.purchasingProductID = productId
                let store = state.store
                return .task(Action.purchaseReceived) {
                    let result = try await storeCreditUsecase.purchase(store: store, productId: productId)
                    let balance = try? await storeCreditUsecase.loadBalance(storeId: store.id)
                    return StoreCreditPurchaseCompletion(result: result, balance: balance)
                }

            case .purchaseReceived(.success(let completion)):
                state.isPurchasing = false
                state.purchasingProductID = nil
                if let balance = completion.balance {
                    state.balance = balance
                }
                switch completion.result {
                case .completed(let result):
                    state.balance = CreditAccount(storeId: state.store.id, balance: result.balance)
                    state.alert = .success("\(result.creditedAmount)ptを追加しました。")
                case .pending:
                    state.alert = .success("購入の確認を待っています。")
                case .cancelled:
                    break
                }
                return .none

            case .purchaseReceived(.failure(let error)):
                state.isPurchasing = false
                state.purchasingProductID = nil
                state.alert = .error("購入を確定できませんでした。\n\(error.message)")
                return .none

            case .historyTapped:
                guard !state.isHistoryLoading else { return .none }
                state.isHistoryLoading = true
                let storeId = state.store.id
                return .task(Action.historyReceived) {
                    try await storeCreditUsecase.loadHistory(storeId: storeId)
                }

            case .historyReceived(.success(let history)):
                state.isHistoryLoading = false
                state.destination = .history(PurchaseHistoryFeature.State(items: history))
                return .none

            case .historyReceived(.failure(let error)):
                state.isHistoryLoading = false
                state.alert = .error("購入履歴を取得できませんでした。\n\(error.message)")
                return .none

            case .destination:
                return .none

            case .alert(.presented(.okTapped)):
                state.alert = nil
                return .none

            case .alert:
                state.alert = nil
                return .none
            }
        }
        .ifLet(\.$destination, action: \.destination)
        .ifLet(\.$alert, action: \.alert)
    }
}

struct StoreCreditPreparation: Equatable {
    let balance: CreditAccount
    let products: [StoreCreditProduct]
    let productErrorMessage: String?
}

struct StoreCreditPurchaseCompletion: Equatable {
    let result: StoreCreditPurchaseResult
    let balance: CreditAccount?
}

extension StoreCreditFeature.Destination.State: Equatable {}
extension StoreCreditFeature.Destination.Action: Equatable {}
