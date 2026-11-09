import ComposableArchitecture
import Shared

@Reducer
struct StoreCreditFeature {
    @ObservableState
    struct State: Equatable {
        let store: AdvertiserStore
        @Shared var storeCreditCatalog: StoreCreditProductCatalog
        var balance: CreditAccount
        var purchaseHistory: [PurchaseHistoryItem] = []
        var visibleHistoryCount = 10
        var isHistoryLoading = false
        var hasLoadedHistory = false
        var isPurchasing = false
        var isRestoring = false
        var purchasingProductID: String?
        var selectedProductID: String?
        @Presents var alert: AlertFeature.State?

        init(
            store: AdvertiserStore,
            balance: CreditAccount,
            storeCreditCatalog: Shared<StoreCreditProductCatalog>
        ) {
            self.store = store
            self.balance = balance
            self._storeCreditCatalog = storeCreditCatalog
        }

        var selectedProduct: StoreCreditProduct? {
            if let selectedProductID,
               let selected = storeCreditCatalog.products.first(where: { $0.id == selectedProductID }) {
                return selected
            }
            return storeCreditCatalog.products.first
        }

        var visiblePurchaseHistory: [PurchaseHistoryItem] {
            Array(purchaseHistory.prefix(visibleHistoryCount))
        }
    }

    @CasePathable
    enum Action: Equatable {
        case onAppear
        case productSelected(String)
        case historyReceived(AppResult<[PurchaseHistoryItem]>)
        case loadMoreHistoryTapped
        case purchaseTapped(String)
        case purchaseReceived(AppResult<StoreCreditPurchaseCompletion>)
        case restoreTapped
        case restoreReceived(AppResult<StoreCreditRestoreOutcome>)
        case alert(PresentationAction<AlertFeature.Action>)
    }

    @Dependency(\.storeCreditUsecase) private var storeCreditUsecase

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                guard !state.isHistoryLoading, !state.hasLoadedHistory else { return .none }
                state.isHistoryLoading = true
                let storeId = state.store.id
                return .task(Action.historyReceived) {
                    try await storeCreditUsecase.loadHistory(storeId: storeId)
                }

            case .productSelected(let productId):
                guard !state.isPurchasing, !state.isRestoring,
                      state.storeCreditCatalog.products.contains(where: { $0.id == productId }) else {
                    return .none
                }
                state.selectedProductID = productId
                return .none

            case .historyReceived(.success(let history)):
                state.isHistoryLoading = false
                state.hasLoadedHistory = true
                state.purchaseHistory = history
                return .none

            case .historyReceived(.failure(let error)):
                state.isHistoryLoading = false
                state.alert = .error("購入履歴を取得できませんでした。\n\(error.message)")
                return .none

            case .loadMoreHistoryTapped:
                state.visibleHistoryCount = min(state.visibleHistoryCount + 10, state.purchaseHistory.count)
                return .none

            case .purchaseTapped(let productId):
                guard !state.isPurchasing, !state.isRestoring,
                      state.storeCreditCatalog.products.contains(where: { $0.id == productId }) else {
                    return .none
                }
                state.isPurchasing = true
                state.purchasingProductID = productId
                let store = state.store
                return .task(Action.purchaseReceived) {
                    let result = try await storeCreditUsecase.purchase(store: store, productId: productId)
                    guard case .completed(let purchaseResult) = result else {
                        return StoreCreditPurchaseCompletion(result: result)
                    }

                    async let balance = try? await storeCreditUsecase.loadBalance(storeId: store.id)
                    async let history = try? await storeCreditUsecase.loadHistory(storeId: store.id)
                    let (refreshedBalance, refreshedHistory) = await (balance, history)
                    return StoreCreditPurchaseCompletion(
                        result: result,
                        balance: refreshedBalance ?? CreditAccount(storeId: store.id, balance: purchaseResult.balance),
                        history: refreshedHistory,
                        refreshErrorMessage: refreshedBalance == nil || refreshedHistory == nil
                            ? "購入は完了しましたが、残高または購入履歴を更新できませんでした。"
                            : nil
                    )
                }

            case .purchaseReceived(.success(let completion)):
                state.isPurchasing = false
                state.purchasingProductID = nil
                if let balance = completion.balance {
                    state.balance = balance
                }
                if let history = completion.history {
                    state.purchaseHistory = history
                    state.hasLoadedHistory = true
                }
                if let refreshErrorMessage = completion.refreshErrorMessage {
                    state.alert = .error(refreshErrorMessage)
                    return .none
                }
                switch completion.result {
                case .completed(let result):
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

            case .restoreTapped:
                guard !state.isPurchasing, !state.isRestoring else { return .none }
                state.isRestoring = true
                let store = state.store
                return .task(Action.restoreReceived) {
                    guard try await storeCreditUsecase.restorePurchases(for: store) else {
                        return .cancelled
                    }
                    async let balance = try? await storeCreditUsecase.loadBalance(storeId: store.id)
                    async let history = try? await storeCreditUsecase.loadHistory(storeId: store.id)
                    let (refreshedBalance, refreshedHistory) = await (balance, history)
                    return .restored(StoreCreditRestoreCompletion(
                        balance: refreshedBalance,
                        history: refreshedHistory,
                        refreshErrorMessage: refreshedBalance == nil || refreshedHistory == nil
                            ? "購入情報の同期後に残高または購入履歴を更新できませんでした。"
                            : nil
                    ))
                }

            case .restoreReceived(.success(.cancelled)):
                state.isRestoring = false
                return .none

            case .restoreReceived(.success(.restored(let completion))):
                state.isRestoring = false
                if let balance = completion.balance {
                    state.balance = balance
                }
                if let history = completion.history {
                    state.purchaseHistory = history
                    state.hasLoadedHistory = true
                }
                if let refreshErrorMessage = completion.refreshErrorMessage {
                    state.alert = .error(refreshErrorMessage)
                } else {
                    state.alert = .success("購入情報を同期しました。")
                }
                return .none

            case .restoreReceived(.failure(let error)):
                state.isRestoring = false
                state.alert = .error("購入情報を同期できませんでした。\n\(error.message)")
                return .none

            case .alert(.presented(.okTapped)):
                state.alert = nil
                return .none

            case .alert:
                state.alert = nil
                return .none
            }
        }
        .ifLet(\.$alert, action: \.alert)
    }
}

struct StoreCreditPurchaseCompletion: Equatable {
    let result: StoreCreditPurchaseResult
    var balance: CreditAccount?
    var history: [PurchaseHistoryItem]?
    var refreshErrorMessage: String?

    init(
        result: StoreCreditPurchaseResult,
        balance: CreditAccount? = nil,
        history: [PurchaseHistoryItem]? = nil,
        refreshErrorMessage: String? = nil
    ) {
        self.result = result
        self.balance = balance
        self.history = history
        self.refreshErrorMessage = refreshErrorMessage
    }
}

struct StoreCreditRestoreCompletion: Equatable {
    let balance: CreditAccount?
    let history: [PurchaseHistoryItem]?
    let refreshErrorMessage: String?
}

enum StoreCreditRestoreOutcome: Equatable {
    case cancelled
    case restored(StoreCreditRestoreCompletion)
}
