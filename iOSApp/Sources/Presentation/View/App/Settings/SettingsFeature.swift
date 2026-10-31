import ComposableArchitecture
import Foundation
import Shared

@Reducer
struct SettingsFeature {

    @Reducer
    enum Destination {
        case login(LoginFeature)
    }

    enum Delegate: Equatable {
        case sceneSelectionChanged(UserRole, Route.ID?)
        case participationChanged(SettingsPreparation)
    }

    enum PendingParticipationChange: Equatable {
        case festival(Festival.ID)
        case district(District.ID?)
    }

    struct ParticipationChangeCompletion: Equatable {
        let didSignOut: Bool
        let error: AppError?
    }

    @ObservableState
    struct State: Equatable {
        var userRole: UserRole
        var festivals: [Festival] = []
        var selectedFestival: Festival? = nil
        var confirmedFestival: Festival? = nil
        var districts: [District] {
            appState?.festivalState.districts.sorted { lhs, rhs in
                if lhs.order != rhs.order {
                    return lhs.order < rhs.order
                }
                return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
            } ?? []
        }
        var selectedDistrict: District? = nil
        var confirmedDistrict: District? = nil
        var isParticipationLoading: Bool = false
        var isSignOutLoading: Bool = false
        var pendingParticipationChange: PendingParticipationChange?
        @Shared fileprivate var appState: AppState?
        var userGuide: URL? = {
            @Dependency(\.values.userGuideUrl) var userGuideURLString
            return URL(string: userGuideURLString)
        }()

        var contact: URL? = {
            @Dependency(\.values.contactURL) var contactURLString
            return URL(string: contactURLString)
        }()
        @Presents var destination: Destination.State? = nil
        @Presents var alert: AlertFeature.State? = nil
        init(
            selection: SceneSelection,
            festivals: [Festival] = [],
            userRole: UserRole = .guest,
            appState: Shared<AppState?> = Shared(value: nil)
        ) {
            self._appState = appState
            self.userRole = userRole
            self.festivals = festivals
            let selectedFestival = appState.wrappedValue?.festivalState.festival
                ?? festivals.first(where: { $0.id == selection.festivalId })
            let selectedDistrict = appState.wrappedValue?.selectedDistrict
            self.selectedFestival = selectedFestival
            self.confirmedFestival = selectedFestival
            self.selectedDistrict = selectedDistrict
            self.confirmedDistrict = selectedDistrict
        }
    }

    @CasePathable
    enum Action: Equatable, BindableAction {
        case binding(BindingAction<State>)
        case loginTapped
        case signOutTapped
        case signOutReceived(VoidAppResult)
        case festivalSelectReceived(AppResult<FestivalSelectionResult>)
        case districtSelectReceived(AppResult<Route.ID?>)
        case participationChangeReceived(ParticipationChangeCompletion)
        case delegate(Delegate)
        case destination(PresentationAction<Destination.Action>)
        case alert(PresentationAction<AlertFeature.Action>)
    }

    @Dependency(SelectFestivalUseCaseKey.self) var selectFestivalUseCase
    @Dependency(SelectDistrictUseCaseKey.self) var selectDistrictUseCase
    @Dependency(SignOutUseCaseKey.self) var signOutUseCase

    var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .binding(\.selectedFestival):
                guard let festival = state.selectedFestival else { return .none }
                guard festival.id != state.confirmedFestival?.id else { return .none }
                if state.userRole != .guest {
                    state.pendingParticipationChange = .festival(festival.id)
                    state.selectedFestival = state.confirmedFestival
                    state.selectedDistrict = state.confirmedDistrict
                    state.alert = AlertFeature.participationChangeConfirmation()
                    return .none
                }
                state.isParticipationLoading = true
                return .task(Action.festivalSelectReceived) { [appState = state.$appState] in
                    try await selectFestivalUseCase(festivalId: festival.id, appState: appState)
                }
                .cancellable(id: SceneSessionCancellationID.active, cancelInFlight: true)
            case .binding(\.selectedDistrict):
                let districtId = state.selectedDistrict?.id
                guard districtId != state.confirmedDistrict?.id else { return .none }
                if state.userRole != .guest {
                    state.pendingParticipationChange = .district(districtId)
                    state.selectedDistrict = state.confirmedDistrict
                    state.alert = AlertFeature.participationChangeConfirmation()
                    return .none
                }
                state.isParticipationLoading = true
                return .task(Action.districtSelectReceived) { [appState = state.$appState] in
                    try await selectDistrictUseCase(districtId: districtId, appState: appState)
                }
                .cancellable(id: SceneSessionCancellationID.active, cancelInFlight: true)
            case .binding:
                return .none
            case .loginTapped:
                state.destination = .login(LoginFeature.State(appState: state.$appState))
                return .none
            case .signOutTapped:
                state.isSignOutLoading = true
                return .task(Action.signOutReceived) {
                    try await signOutUseCase()
                }
                .cancellable(id: SceneSessionCancellationID.active, cancelInFlight: true)
            case .signOutReceived(.failure(let error)):
                state.isSignOutLoading = false
                state.alert = AlertFeature.error("情報の取得に失敗しました \(error.message)")
                return .none
            case .signOutReceived(.success):
                state.isSignOutLoading = false
                return .none
            case .festivalSelectReceived(.success(let result)):
                if case .changed = result {
                    state.selectedDistrict = nil
                }
                state.confirmedFestival = state.selectedFestival
                state.confirmedDistrict = state.selectedDistrict
                state.isParticipationLoading = false
                guard case .changed(let userRole) = result else { return .none }
                return .send(.delegate(.sceneSelectionChanged(userRole, nil)))
            case .districtSelectReceived(.success(let routeId)):
                state.isParticipationLoading = false
                state.confirmedDistrict = state.selectedDistrict
                return .send(.delegate(.sceneSelectionChanged(state.userRole, routeId)))
            case .participationChangeReceived(let completion):
                state.isParticipationLoading = false
                state.pendingParticipationChange = nil

                guard completion.didSignOut else {
                    if let error = completion.error {
                        state.alert = .error("情報の取得に失敗しました \(error.message)")
                    }
                    return .none
                }

                state.userRole = .guest
                if completion.error == nil {
                    state.selectedFestival = state.appState?.festivalState.festival
                        ?? state.selectedFestival
                    state.selectedDistrict = state.appState?.selectedDistrict
                    state.confirmedFestival = state.selectedFestival
                    state.confirmedDistrict = state.selectedDistrict
                }

                let preparation = SettingsPreparation(
                    festivals: state.festivals,
                    selection: SceneSelection(
                        festivalId: state.selectedFestival?.id,
                        districtId: state.selectedDistrict?.id
                    )
                )
                if let error = completion.error {
                    state.alert = .error("情報の取得に失敗しました \(error.message)")
                }
                return .send(.delegate(.participationChanged(preparation)))
            case .festivalSelectReceived(.failure(let error)),
                 .districtSelectReceived(.failure(let error)):
                state.isParticipationLoading = false
                state.alert = AlertFeature.error("情報の取得に失敗しました \(error.message)")
                return .none
            case .destination:
                return .none
            case .delegate:
                return .none
            case .alert(.presented(.confirmTapped)):
                guard let pendingChange = state.pendingParticipationChange else {
                    state.alert = nil
                    return .none
                }
                state.alert = nil
                state.isParticipationLoading = true
                return .run { [appState = state.$appState] send in
                    var didSignOut = false
                    do {
                        try await signOutUseCase()
                        didSignOut = true
                        switch pendingChange {
                        case .festival(let festivalId):
                            _ = try await selectFestivalUseCase(
                                festivalId: festivalId,
                                appState: appState,
                                signOutCurrentUser: false
                            )
                        case .district(let districtId):
                            _ = try await selectDistrictUseCase(
                                districtId: districtId,
                                appState: appState
                            )
                        }
                        await send(.participationChangeReceived(.init(
                            didSignOut: didSignOut,
                            error: nil
                        )))
                    } catch {
                        await send(.participationChangeReceived(.init(
                            didSignOut: didSignOut,
                            error: error.asAppError
                        )))
                    }
                }
                .cancellable(id: SceneSessionCancellationID.active, cancelInFlight: true)
            case .alert(.presented(.cancelTapped)), .alert(.dismiss):
                state.alert = nil
                state.pendingParticipationChange = nil
                state.selectedFestival = state.confirmedFestival
                state.selectedDistrict = state.confirmedDistrict
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

struct SettingsPreparation: Equatable {
    let festivals: [Festival]
    let selection: SceneSelection
}

extension SettingsFeature.Destination.State: Equatable {}
extension SettingsFeature.Destination.Action: Equatable {}
