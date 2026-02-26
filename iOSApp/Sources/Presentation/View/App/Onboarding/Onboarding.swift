//
//  Onboarding.swift
//  MaTool
//
//  Created by 松下和也 on 2025/05/24.
//

import ComposableArchitecture
import Foundation
import Shared
import SQLiteData

@Reducer
struct OnboardingFeature {
    
    @ObservableState
    struct State: Equatable {
        @FetchAll var festivals: [Festival]
        @FetchAll var districts: [District]
        
        var selectedFestival: Festival? {
            didSet {
                self._districts = FetchAll(festivalId: selectedFestival?.id)
            }
        }
        @Shared var launchState: LaunchState
        
        var festivalErrorMessaage: String?
        var isLoading: Bool = false
        
        init(launchState: Shared<LaunchState>) {
            self._festivals = FetchAll()
            self._launchState = launchState
        }
    }
    
    @CasePathable
    enum Action: Equatable, BindableAction {
        case binding(BindingAction<State>)
        case externalGuestTapped
        case adminTapped
        case districtSelected(District)
        case festivalDidSet(VoidTaskResult)
        case districtDidSet(TaskResult<Route.ID?>)
    }
    
    @Dependency(SceneUsecaseKey.self) var sceneUsecase
    
    var body: some ReducerOf<OnboardingFeature> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .binding(\.selectedFestival):
                guard let festival = state.selectedFestival else { return .none }
                state.isLoading = true
                return .task(Action.festivalDidSet) {
                    _ = try await sceneUsecase.select(festivalId: festival.id)
                    return
                }
            case .binding:
                return .none
            case .externalGuestTapped,
                .adminTapped:
                guard state.selectedFestival != nil else {
                    state.festivalErrorMessaage = "祭典を選択してください。"
                    return .none
                }
                state.$launchState.withLock{ $0 = .festival(.guest) }
                return .none
            case .districtSelected(let district):
                guard let festival = state.selectedFestival, district.festivalId == festival.id  else {
                    state.festivalErrorMessaage = "祭典を選択してください。"
                    return .none
                }
                return .task(Action.districtDidSet) {
                    try await sceneUsecase.select(districtId: district.id)
                }
            case .festivalDidSet(.success):
                state.isLoading = false
                return .none
            case .festivalDidSet(.failure(_)):
                state.isLoading = false
                return .none
            case .districtDidSet(.success(let routeId)):
                state.isLoading = false
                state.$launchState.withLock{ $0 = .district(.guest, routeId) }
                return .none
            case .districtDidSet(.failure(_)):
                state.isLoading = false
                return .none
            }
        }
    }
}
