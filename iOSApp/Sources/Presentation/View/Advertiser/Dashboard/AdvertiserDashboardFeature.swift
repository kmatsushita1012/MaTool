import ComposableArchitecture
import Dependencies
import Shared

@Reducer
struct AdvertiserDashboardFeature {
    @Reducer
    enum Destination {
        case storeCreate(StoreEditFeature)
        case storeDashboard(StoreDashboardFeature)
        case changePassword(ChangePasswordFeature)
        case updateEmail(UpdateEmailFeature)
        case settings(SettingsFeature)
    }

    @ObservableState
    struct State: Equatable {
        @Shared fileprivate var appState: AppState?
        let userRole: UserRole
        var stores: [AdvertiserStore] = []
        var festivals: [Festival] = []
        var isLoading = false
        var isSigningOut = false
        var isSettingsLoading = false
        var festivalLoadErrorMessage: String?
        @Presents var destination: Destination.State?
        @Presents var alert: AlertFeature.State?

        init(userRole: UserRole, appState: Shared<AppState?>) {
            self._appState = appState
            self.userRole = userRole
        }
    }

    @CasePathable
    enum Action: Equatable {
        case onAppear
        case loadReceived(AdvertiserDashboardPreparation)
        case addStoreTapped
        case storeTapped(AdvertiserStore)
        case changePasswordTapped
        case updateEmailTapped
        case settingsTapped
        case settingsPrepared(AppResult<SettingsPreparation>)
        case signOutTapped
        case signOutReceived(VoidAppResult)
        case destination(PresentationAction<Destination.Action>)
        case alert(PresentationAction<AlertFeature.Action>)
    }

    @Dependency(\.advertiserDashboardUsecase) private var dashboardUsecase
    @Dependency(SignOutUseCaseKey.self) private var signOutUseCase
    @Dependency(FetchFestivalListUseCaseKey.self) private var fetchFestivalListUseCase
    @Dependency(GetSceneSelectionUseCaseKey.self) private var getSceneSelectionUseCase

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                guard !state.isLoading else { return .none }
                state.isLoading = true
                let dashboardUsecase = self.dashboardUsecase
                return .run { send in
                    let preparation = await dashboardUsecase()
                    await send(.loadReceived(preparation))
                }

            case .loadReceived(let preparation):
                state.isLoading = false
                switch preparation.stores {
                case .success(let stores):
                    state.stores = stores.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
                case .failure(let error):
                    state.alert = .error("店舗情報を取得できませんでした。\n\(error.message)")
                }
                switch preparation.festivals {
                case .success(let festivals):
                    state.festivals = festivals
                    state.festivalLoadErrorMessage = nil
                case .failure(let error):
                    state.festivalLoadErrorMessage = error.message
                }
                return .none

            case .addStoreTapped:
                if let errorMessage = state.festivalLoadErrorMessage {
                    state.alert = .error("祭典情報を取得できませんでした。\n\(errorMessage)")
                    return .none
                }
                guard !state.festivals.isEmpty else {
                    state.alert = .error("店舗を登録できる祭典がありません。")
                    return .none
                }
                state.destination = .storeCreate(StoreEditFeature.State(festivals: state.festivals))
                return .none

            case .storeTapped(let store):
                state.destination = .storeDashboard(StoreDashboardFeature.State(
                    store: store,
                    festivals: state.festivals
                ))
                return .none

            case .changePasswordTapped:
                state.destination = .changePassword(ChangePasswordFeature.State())
                return .none

            case .updateEmailTapped:
                state.destination = .updateEmail(UpdateEmailFeature.State())
                return .none

            case .settingsTapped:
                guard !state.isSettingsLoading else { return .none }
                state.isSettingsLoading = true
                return .task(Action.settingsPrepared) {
                    let festivals = try await fetchFestivalListUseCase()
                    let selection = getSceneSelectionUseCase()
                    return SettingsPreparation(festivals: festivals, selection: selection)
                }

            case .settingsPrepared(.success(let preparation)):
                state.isSettingsLoading = false
                state.destination = .settings(SettingsFeature.State(
                    selection: preparation.selection,
                    festivals: preparation.festivals,
                    userRole: state.userRole,
                    appState: state.$appState
                ))
                return .none

            case .settingsPrepared(.failure(let error)):
                state.isSettingsLoading = false
                state.alert = .error("設定画面の準備に失敗しました。\n\(error.message)")
                return .none

            case .destination(.presented(.storeCreate(.saveReceived(.success(.created(let store)))))):
                state.stores.upsert(store)
                state.destination = .storeDashboard(StoreDashboardFeature.State(
                    store: store,
                    festivals: state.festivals
                ))
                return .none

            case .destination(.presented(.storeDashboard(let childAction))):
                switch childAction {
                case .pauseReceived(.success(let store)),
                     .destination(.presented(.storeEdit(.saveReceived(.success(.updated(let store)))))),
                     .adImagesSaveReceived(.success(let store)):
                    state.stores.upsert(store)
                default:
                    break
                }
                return .none

            case .destination(.presented(.changePassword(.received(.success)))):
                state.destination = nil
                state.alert = .success("パスワードが変更されました")
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

extension AdvertiserDashboardFeature.Destination.State: Equatable {}
extension AdvertiserDashboardFeature.Destination.Action: Equatable {}
