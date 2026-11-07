import ComposableArchitecture
import Dependencies
import Shared

@Reducer
struct AdvertiserDashboardFeature {
    @Reducer
    enum Destination {
        case storeEdit(StoreEditFeature)
    }

    @ObservableState
    struct State: Equatable {
        var stores: [AdvertiserStore] = []
        var festivals: [Festival] = []
        var isLoading = false
        var isSigningOut = false
        @Presents var destination: Destination.State?
        @Presents var alert: AlertFeature.State?
    }

    @CasePathable
    enum Action: Equatable {
        case onAppear
        case loadReceived(AppResult<AdvertiserDashboardData>)
        case addStoreTapped
        case storeTapped(AdvertiserStore)
        case signOutTapped
        case signOutReceived(VoidAppResult)
        case destination(PresentationAction<Destination.Action>)
        case alert(PresentationAction<AlertFeature.Action>)
    }

    @Dependency(\.advertiserStoreUsecase) private var storeUsecase
    @Dependency(FetchFestivalListUseCaseKey.self) private var fetchFestivalListUseCase
    @Dependency(\.storeCreditUsecase) private var storeCreditUsecase
    @Dependency(SignOutUseCaseKey.self) private var signOutUseCase

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                guard !state.isLoading else { return .none }
                state.isLoading = true
                return .task(Action.loadReceived) {
                    async let stores = storeUsecase.loadOwnedStores()
                    async let festivals = fetchFestivalListUseCase()
                    let result = try await AdvertiserDashboardData(stores: stores, festivals: festivals)
                    await storeCreditUsecase.recoverUnfinishedPurchases(for: result.stores)
                    return result
                }

            case .loadReceived(.success(let data)):
                state.isLoading = false
                state.stores = data.stores.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
                state.festivals = data.festivals
                return .none

            case .loadReceived(.failure(let error)):
                state.isLoading = false
                state.alert = .error("店舗情報を取得できませんでした。\n\(error.message)")
                return .none

            case .addStoreTapped:
                guard !state.festivals.isEmpty else {
                    state.alert = .error("店舗を登録できる祭典がありません。")
                    return .none
                }
                state.destination = .storeEdit(StoreEditFeature.State(festivals: state.festivals))
                return .none

            case .storeTapped(let store):
                state.destination = .storeEdit(StoreEditFeature.State(store: store, festivals: state.festivals))
                return .none

            case .destination(.presented(.storeEdit(.saveReceived(.success(let result))))):
                let store: AdvertiserStore
                switch result {
                case .created(let savedStore), .updated(let savedStore):
                    store = savedStore
                }
                state.stores.upsert(store)
                return .none

            case .signOutTapped:
                guard !state.isSigningOut else { return .none }
                state.isSigningOut = true
                return .task(Action.signOutReceived) {
                    try await signOutUseCase()
                }

            case .signOutReceived(.failure(let error)):
                state.isSigningOut = false
                state.alert = .error("ログアウトに失敗しました。\n\(error.message)")
                return .none

            case .signOutReceived(.success):
                state.isSigningOut = false
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

struct AdvertiserDashboardData: Equatable {
    let stores: [AdvertiserStore]
    let festivals: [Festival]
}

extension AdvertiserDashboardFeature.Destination.State: Equatable {}
extension AdvertiserDashboardFeature.Destination.Action: Equatable {}
