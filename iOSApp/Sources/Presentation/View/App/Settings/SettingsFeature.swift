//
//  SettingsFeature.swift
//  MaTool
//
//  Created by 松下和也 on 2025/04/20.
//

import Foundation
import ComposableArchitecture
import Shared
import SQLiteData

@Reducer
struct SettingsFeature {
    
    @ObservableState
    struct State: Equatable {
        var isOfflineMode: Bool = false
        @FetchAll var festivals: [Festival]
        var selectedFestival: Festival? = nil
        @FetchAll var districts: [District]
        var selectedDistrict: District? = nil
        var isLoading: Bool = false
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
        
        init(selection: SceneSelection) {
            self.selectedFestival = selection.festivalId.flatMap { FetchOne(Festival.find($0)).wrappedValue }
            self.selectedDistrict = selection.districtId.flatMap { FetchOne(District.find($0)).wrappedValue }
            self._festivals = FetchAll()
            self._districts = FetchAll(District.where{ $0.festivalId.eq(selectedFestival?.id) }.order(by: \.order))
        }
    }

    @CasePathable
    enum Action: Equatable, BindableAction {
        case binding(BindingAction<State>)
        case dismissTapped
        case signOutTapped
        case signOutReceived(AppResult<UserRole>)
        case festivalSelectReceived(AppResult<FestivalSelectionResult>)
        case districtSelectReceived(AppResult<Route.ID?>)
        case alert(PresentationAction<AlertFeature.Action>)
    }
    
    @Dependency(\.dismiss) var dismiss
    @Dependency(\.authService) var authService
    @Dependency(SceneUsecaseKey.self) var sceneUsecase
    
    var body: some ReducerOf<SettingsFeature> {
        BindingReducer()
        Reduce{ state, action in
            switch action {
            case .binding(\.selectedFestival):
                guard let festival = state.selectedFestival else { return .none }
                state.isLoading = true
                return .task(Action.festivalSelectReceived) {
                    try await sceneUsecase.select(festivalId: festival.id)
                }
            case .binding(\.selectedDistrict):
                let districtId = state.selectedDistrict?.id
                state.isLoading = true
                return .task(Action.districtSelectReceived) {
                    try await sceneUsecase.select(districtId: districtId)
                }
            case .binding:
                return .none
            case .signOutTapped:
                return .task(Action.signOutReceived) {
                    try await authService.signOut()
                }
            case .signOutReceived(.success):
                state.alert = AlertFeature.success("ログアウトしました")
                return .none
            case .signOutReceived(.failure(let error)):
                state.alert = AlertFeature.error("情報の取得に失敗しました \(error.message)")
                return .none
            case .festivalSelectReceived(.success(let result)):
                if case .changed = result {
                    state.selectedDistrict = nil
                    state.$districts = FetchAll(District.where{ $0.festivalId.eq(state.selectedFestival?.id)}.order(by: \.order))
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
