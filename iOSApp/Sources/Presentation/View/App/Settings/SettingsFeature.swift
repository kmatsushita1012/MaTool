//
//  SettingsFeature.swift
//  MaTool
//
//  Created by 松下和也 on 2025/04/20.
//

import Foundation
import ComposableArchitecture
import Shared

@Reducer
struct SettingsFeature {
    
    @ObservableState
    struct State: Equatable {
        var isOfflineMode: Bool = false
        var festivals: [Festival] = []
        var selectedFestival: Festival? = nil
        var districts: [District] {
            appState?.festivalState.districts ?? []
        }
        var selectedDistrict: District? = nil
        var isLoading: Bool = false
        @Shared fileprivate var appState: AppState?
        var userGuide: URL = {
            @Dependency(\.values.userGuideUrl) var userGuideURLString
            return URL(string: userGuideURLString)!
        }()
        
        var contact: URL = {
            @Dependency(\.values.contactURL) var contactURLString
            return URL(string: contactURLString)!
        }()
        @Presents var alert: AlertFeature.State? = nil
        var isDismissEnabled: Bool {
            !isLoading && (selectedFestival != nil || isOfflineMode)
        }
        
        init(
            selection: SceneSelection,
            festivals: [Festival] = [],
            appState: Shared<AppState?> = Shared(value: nil)
        ) {
            self._appState = appState
            self.festivals = festivals
            self.selectedFestival = appState.wrappedValue?.festivalState.festival
                ?? festivals.first(where: { $0.id == selection.festivalId })
            self.selectedDistrict = appState.wrappedValue?.districtState.flatMap { districtState in
                appState.wrappedValue?.festivalState.districts.first { $0.id == districtState.districtId }
            } ?? nil
        }
    }

    @CasePathable
    enum Action: Equatable, BindableAction {
        case binding(BindingAction<State>)
        case dismissTapped
        case signOutTapped
        case signOutReceived(VoidAppResult)
        case festivalSelectReceived(AppResult<FestivalSelectionResult>)
        case districtSelectReceived(AppResult<Route.ID?>)
        case alert(PresentationAction<AlertFeature.Action>)
    }
    
    @Dependency(\.dismiss) var dismiss
    @Dependency(SelectFestivalUseCaseKey.self) var selectFestivalUseCase
    @Dependency(SelectDistrictUseCaseKey.self) var selectDistrictUseCase
    @Dependency(SignOutUseCaseKey.self) var signOutUseCase
    
    var body: some ReducerOf<SettingsFeature> {
        BindingReducer()
        Reduce{ state, action in
            switch action {
            case .binding(\.selectedFestival):
                guard let festival = state.selectedFestival else { return .none }
                state.isLoading = true
                return .task(Action.festivalSelectReceived) { [appState = state.$appState] in
                    try await selectFestivalUseCase(festivalId: festival.id, appState: appState)
                }
                .cancellable(id: SceneSessionCancellationID.active, cancelInFlight: true)
            case .binding(\.selectedDistrict):
                let districtId = state.selectedDistrict?.id
                state.isLoading = true
                return .task(Action.districtSelectReceived) { [appState = state.$appState] in
                    try await selectDistrictUseCase(districtId: districtId, appState: appState)
                }
                .cancellable(id: SceneSessionCancellationID.active, cancelInFlight: true)
            case .binding:
                return .none
            case .signOutTapped:
                state.isLoading = true
                return .task(Action.signOutReceived) {
                    try await signOutUseCase()
                }
                .cancellable(id: SceneSessionCancellationID.active, cancelInFlight: true)
            case .signOutReceived(.failure(let error)):
                state.isLoading = false
                state.alert = AlertFeature.error("情報の取得に失敗しました \(error.message)")
                return .none
            case .signOutReceived(.success):
                return .none
            case .festivalSelectReceived(.success(let result)):
                if case .changed = result {
                    state.selectedDistrict = nil
                }
                state.isLoading = false
                return .none
            case .districtSelectReceived(.success(_)):
                state.isLoading = false
                return .none
            case .festivalSelectReceived(.failure(let error)),
                .districtSelectReceived(.failure(let error)):
                state.isLoading = false
                state.alert = AlertFeature.error("情報の取得に失敗しました \(error.message)")
                return .none
            case .alert:
                state.alert = nil
                return .none
            case .dismissTapped:
                return .dismiss
            }
        }
    }
}
