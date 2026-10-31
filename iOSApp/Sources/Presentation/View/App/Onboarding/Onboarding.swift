//
//  Onboarding.swift
//  MaTool
//
//  Created by 松下和也 on 2025/05/24.
//

import ComposableArchitecture
import Foundation
import Shared

@Reducer
struct OnboardingFeature {
    
    @ObservableState
    struct State: Equatable {
        var festivals: [Festival] = []
        var selectedFestival: Festival?

        var districts: [District] {
            appState?.festivalState.districts ?? []
        }
        @Shared var launchState: LaunchState
        @Shared fileprivate var appState: AppState?
        
        var festivalErrorMessaage: String?
        var isFestivalLoading: Bool = false
        var isDistrictLoading: Bool = false
        
        init(launchState: Shared<LaunchState>, appState: Shared<AppState?>) {
            self._launchState = launchState
            self._appState = appState
        }
    }
    
    @CasePathable
    enum Action: Equatable, BindableAction {
        case binding(BindingAction<State>)
        case onAppear
        case festivalsLoaded(AppResult<[Festival]>)
        case delegate(Delegate)
        case externalGuestTapped
        case adminTapped
        case districtSelected(District)
        case festivalDidSet(VoidAppResult)
        case districtDidSet(AppResult<Route.ID?>)
    }

    enum Delegate: Equatable {
        case continueAsGuest
        case districtSelected(Route.ID?)
    }
    
    @Dependency(SelectFestivalUseCaseKey.self) var selectFestivalUseCase
    @Dependency(SelectDistrictUseCaseKey.self) var selectDistrictUseCase
    @Dependency(FetchFestivalListUseCaseKey.self) var fetchFestivalListUseCase
    
    var body: some ReducerOf<OnboardingFeature> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .onAppear:
                return .task(Action.festivalsLoaded) {
                    try await fetchFestivalListUseCase()
                }
            case .festivalsLoaded(.success(let festivals)):
                state.festivals = festivals
                return .none
            case .festivalsLoaded(.failure(let error)):
                state.festivalErrorMessaage = error.message
                return .none
            case .delegate:
                return .none
            case .binding(\.selectedFestival):
                guard let festival = state.selectedFestival else { return .none }
                state.isFestivalLoading = true
                return .task(Action.festivalDidSet) { [appState = state.$appState] in
                    _ = try await selectFestivalUseCase(festivalId: festival.id, appState: appState)
                    return
                }
                .cancellable(id: SceneSessionCancellationID.active, cancelInFlight: true)
            case .binding:
                return .none
            case .externalGuestTapped,
                .adminTapped:
                guard state.selectedFestival != nil else {
                    state.festivalErrorMessaage = "祭典を選択してください。"
                    return .none
                }
                state.$launchState.withLock{ $0 = .festival(.guest) }
                return .send(.delegate(.continueAsGuest))
            case .districtSelected(let district):
                guard let festival = state.selectedFestival, district.festivalId == festival.id  else {
                    state.festivalErrorMessaage = "祭典を選択してください。"
                    return .none
                }
                state.isDistrictLoading = true
                return .task(Action.districtDidSet) { [appState = state.$appState] in
                    try await selectDistrictUseCase(districtId: district.id, appState: appState)
                }
                .cancellable(id: SceneSessionCancellationID.active, cancelInFlight: true)
            case .festivalDidSet(.success):
                state.isFestivalLoading = false
                return .none
            case .festivalDidSet(.failure(_)):
                state.isFestivalLoading = false
                return .none
            case .districtDidSet(.success(let routeId)):
                state.isDistrictLoading = false
                state.$launchState.withLock{ $0 = .district(.guest, routeId) }
                return .send(.delegate(.districtSelected(routeId)))
            case .districtDidSet(.failure(_)):
                state.isDistrictLoading = false
                return .none
            }
        }
    }
}
