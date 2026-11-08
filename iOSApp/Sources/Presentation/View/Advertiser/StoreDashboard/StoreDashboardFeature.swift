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
        var balance: CreditAccount?
        var isBalanceLoading = false
        var isPauseUpdating = false
        var isAdImageSaving = false
        var ownerPausedBeforeUpdate: Bool?
        @Presents var destination: Destination.State?
        @Presents var alert: AlertFeature.State?

        var nextAction: NextAction? {
            guard let balance else { return nil }
            if store.bannerImagePath == nil { return .banner }
            if store.interstitialImagePath == nil { return .interstitial }
            if balance.balance < 2 { return .credit }
            return nil
        }

        init(store: AdvertiserStore, festivals: [Festival]) {
            self.store = store
            self.festivals = festivals
        }
    }

    enum NextAction: Equatable {
        case banner
        case interstitial
        case credit

        var title: String {
            switch self {
            case .banner: "バナー画像を設定"
            case .interstitial: "全画面画像を設定"
            case .credit: "クレジットを購入"
            }
        }
    }

    @CasePathable
    enum Action: Equatable {
        case onAppear
        case balanceReceived(AppResult<CreditAccount>)
        case nextActionTapped
        case bannerTapped
        case interstitialTapped
        case creditTapped
        case editTapped
        case ownerPausedChanged(Bool)
        case pauseReceived(AppResult<AdvertiserStore>)
        case saveAdImagesTapped
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
                return .none

            case .balanceReceived(.failure(let error)):
                state.isBalanceLoading = false
                state.alert = .error("クレジット残高を取得できませんでした。\n\(error.message)")
                return .none

            case .nextActionTapped:
                guard let nextAction = state.nextAction else { return .none }
                switch nextAction {
                case .banner:
                    state.destination = .storeAdImage(makeImageEditState(store: state.store, mode: .banner))
                case .interstitial:
                    state.destination = .storeAdImage(makeImageEditState(store: state.store, mode: .interstitial))
                case .credit:
                    state.destination = .credit(StoreCreditFeature.State(store: state.store))
                }
                return .none

            case .bannerTapped:
                state.destination = .storeAdImage(makeImageEditState(store: state.store, mode: .banner))
                return .none

            case .interstitialTapped:
                state.destination = .storeAdImage(makeImageEditState(store: state.store, mode: .interstitial))
                return .none

            case .creditTapped:
                state.destination = .credit(StoreCreditFeature.State(store: state.store))
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

            case .saveAdImagesTapped:
                guard !state.isAdImageSaving,
                      let imageEditor = state.destination?.storeAdImage else {
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
                state.isAdImageSaving = true
                return .task(Action.adImagesSaveReceived) {
                    try await storeUsecase.save(updatedStore)
                }

            case .adImagesSaveReceived(.success(let store)):
                state.isAdImageSaving = false
                state.store = store
                state.destination = nil
                return .none

            case .adImagesSaveReceived(.failure(let error)):
                state.isAdImageSaving = false
                state.alert = .error("画像の保存に失敗しました。\n\(error.message)")
                return .none

            case .destination(.presented(.storeEdit(.saveReceived(.success(.updated(let store)))))):
                state.store = store
                state.destination = nil
                return .none

            case .destination(.presented(.credit(.loadReceived(.success(let preparation))))):
                state.balance = preparation.balance
                return .none

            case .destination(.presented(.credit(.purchaseReceived(.success(let completion))))):
                if let balance = completion.balance {
                    state.balance = balance
                } else if case .completed(let result) = completion.result {
                    state.balance = CreditAccount(storeId: state.store.id, balance: result.balance)
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
