import ComposableArchitecture
import Shared

@Reducer
struct StoreDashboardFeature {
    @Reducer
    enum Destination {
        case storeEdit(StoreEditFeature)
        case storeAdImage(ImageEditFeature)
        case credit(StoreCreditFeature)
    }

    @ObservableState
    struct State: Equatable {
        var store: AdvertiserStore
        let festivals: [Festival]
        @Shared var storeCreditCatalog: StoreCreditProductCatalog
        var balance: CreditAccount?
        var isBalanceLoading = false
        var hasPurchasedCredits: Bool?
        var isPauseUpdating = false
        var ownerPausedBeforeUpdate: Bool?
        @Presents var destination: Destination.State?
        @Presents var alert: AlertFeature.State?

        init(
            store: AdvertiserStore,
            festivals: [Festival],
            storeCreditCatalog: Shared<StoreCreditProductCatalog> = Shared(value: StoreCreditProductCatalog())
        ) {
            self.store = store
            self.festivals = festivals
            self._storeCreditCatalog = storeCreditCatalog
        }
    }

    @CasePathable
    enum Action: Equatable {
        case onAppear
        case balanceReceived(AppResult<CreditAccount>)
        case bannerTapped
        case interstitialTapped
        case creditTapped
        case editTapped
        case ownerPausedChanged(Bool)
        case pauseReceived(AppResult<AdvertiserStore>)
        case adImagesSaveReceived(AppResult<AdvertiserStore>)
        case destination(PresentationAction<Destination.Action>)
        case alert(PresentationAction<AlertFeature.Action>)
    }

    @Dependency(\.storeCreditUsecase) private var creditUsecase
    @Dependency(\.advertiserStoreUsecase) private var storeUsecase

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                guard state.balance == nil, !state.isBalanceLoading else { return .none }
                state.isBalanceLoading = true
                let storeId = state.store.id
                return .task(Action.balanceReceived) {
                    try await creditUsecase.loadBalance(storeId: storeId)
                }

            case .balanceReceived(.success(let balance)):
                state.isBalanceLoading = false
                state.balance = balance
                state.hasPurchasedCredits = balance.lastPurchasedAt != nil
                return .none

            case .balanceReceived(.failure(let error)):
                state.isBalanceLoading = false
                state.alert = .error("クレジット残高を取得できませんでした。\n\(error.message)")
                return .none

            case .bannerTapped:
                state.destination = .storeAdImage(makeImageEditState(store: state.store, mode: .banner))
                return .none

            case .interstitialTapped:
                state.destination = .storeAdImage(makeImageEditState(store: state.store, mode: .interstitial))
                return .none

            case .creditTapped:
                guard let balance = state.balance else { return .none }
                state.destination = .credit(StoreCreditFeature.State(
                    store: state.store,
                    balance: balance,
                    storeCreditCatalog: state.$storeCreditCatalog
                ))
                return .none

            case .editTapped:
                state.destination = .storeEdit(StoreEditFeature.State(
                    store: state.store,
                    festivals: state.festivals
                ))
                return .none

            case .ownerPausedChanged(let isPaused):
                guard !state.isPauseUpdating, state.store.ownerPaused != isPaused else { return .none }
                var updatedStore = state.store
                state.ownerPausedBeforeUpdate = updatedStore.ownerPaused
                updatedStore.ownerPaused = isPaused
                state.store = updatedStore
                state.isPauseUpdating = true
                return .task(Action.pauseReceived) {
                    try await storeUsecase.save(updatedStore)
                }

            case .pauseReceived(.success(let store)):
                state.isPauseUpdating = false
                state.ownerPausedBeforeUpdate = nil
                state.store = store
                return .none

            case .pauseReceived(.failure(let error)):
                state.isPauseUpdating = false
                if let ownerPausedBeforeUpdate = state.ownerPausedBeforeUpdate {
                    state.store.ownerPaused = ownerPausedBeforeUpdate
                }
                state.ownerPausedBeforeUpdate = nil
                state.alert = .error("広告配信状態を更新できませんでした。\n\(error.message)")
                return .none

            case .destination(.presented(.storeAdImage(.saveTapped))):
                guard let imageEditor = state.destination?.storeAdImage,
                      !imageEditor.isSaving else {
                    return .none
                }
                let originalImage = ImagePath(
                    light: state.store.bannerImagePath,
                    dark: state.store.interstitialImagePath
                )
                guard let image = imageEditor.imagePath(applyingTo: originalImage) else {
                    state.alert = .error("画像のアップロードが完了するまで保存できません。")
                    return .none
                }
                var updatedStore = state.store
                updatedStore.bannerImagePath = image.light
                updatedStore.interstitialImagePath = image.dark
                var savingImageEditor = imageEditor
                savingImageEditor.isSaving = true
                state.destination = .storeAdImage(savingImageEditor)
                return .task(Action.adImagesSaveReceived) {
                    try await storeUsecase.save(updatedStore)
                }

            case .adImagesSaveReceived(.success(let store)):
                state.store = store
                state.destination = nil
                return .none

            case .adImagesSaveReceived(.failure(let error)):
                if var imageEditor = state.destination?.storeAdImage {
                    imageEditor.isSaving = false
                    imageEditor.alert = .error("画像の保存に失敗しました。\n\(error.message)")
                    state.destination = .storeAdImage(imageEditor)
                } else {
                    state.alert = .error("画像の保存に失敗しました。\n\(error.message)")
                }
                return .none

            case .destination(.presented(.storeEdit(.saveReceived(.success(.updated(let store)))))):
                state.store = store
                state.destination = nil
                return .none

            case .destination(.presented(.credit(.purchaseReceived(.success(let completion))))):
                if let balance = completion.balance {
                    state.balance = balance
                } else if case .completed(let result) = completion.result {
                    state.balance = CreditAccount(storeId: state.store.id, balance: result.balance)
                }
                if case .completed = completion.result {
                    state.hasPurchasedCredits = true
                }
                return .none

            case .destination(.presented(.credit(.restoreReceived(.success(.restored(let completion)))))):
                if let balance = completion.balance {
                    state.balance = balance
                    if balance.lastPurchasedAt != nil {
                        state.hasPurchasedCredits = true
                    }
                }
                if completion.history?.isEmpty == false {
                    state.hasPurchasedCredits = true
                }
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

    private func makeImageEditState(
        store: AdvertiserStore,
        mode: ImageEditFeature.Mode
    ) -> ImageEditFeature.State {
        ImageEditFeature.State(
            targetType: .store,
            targetID: store.id,
            image: ImagePath(light: store.bannerImagePath, dark: store.interstitialImagePath),
            selectedMode: mode
        )
    }
}

extension StoreDashboardFeature.Destination.State: Equatable {}
extension StoreDashboardFeature.Destination.Action: Equatable {}
