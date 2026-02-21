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
        @FetchAll var rawDistricts: [District]
        var districts: [District] { rawDistricts.sorted() }
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
            selectedFestival != nil || isOfflineMode
        }
        
        init() {
            @Dependency(\.userDefaultsClient) var userDefaultsClient
            @Dependency(\.values.defaultFestivalKey) var defaultFestivalKey
            @Dependency(\.values.defaultDistrictKey) var defaultDistrictKey
            self.selectedFestival = FetchOne(Festival.where{ $0.id.eq(userDefaultsClient.string(defaultFestivalKey))}).wrappedValue
            self.selectedDistrict = FetchOne(District.where{ $0.id.eq(userDefaultsClient.string(defaultDistrictKey))}).wrappedValue
            self._rawDistricts = FetchAll(District.where{ $0.festivalId.eq(selectedFestival?.id) })
        }
    }

    @CasePathable
    enum Action: Equatable, BindableAction {
        case binding(BindingAction<State>)
        case dismissTapped
        case signOutTapped
        case signOutReceived(TaskResult<UserRole>)
        case districtsReceived(VoidTaskResult)
        case alert(PresentationAction<AlertFeature.Action>)
    }
    
    @Dependency(\.dismiss) var dismiss
    @Dependency(\.authService) var authService
    @Dependency(DistrictDataFetcherKey.self) var districtDataFetcher
    @Dependency(\.userDefaultsClient) var userDefaultsClient
    @Dependency(\.values.defaultFestivalKey) var defaultFestivalKey
    @Dependency(\.values.defaultDistrictKey) var defaultDistrictKey
    
    var body: some ReducerOf<SettingsFeature> {
        BindingReducer()
        Reduce{ state, action in
            switch action {
            case .binding(\.selectedFestival):
                state.selectedDistrict = nil
                userDefaultsClient.setString(state.selectedDistrict?.id, defaultDistrictKey)
                userDefaultsClient.setString(state.selectedFestival?.id, defaultFestivalKey)
                guard let festival = state.selectedFestival else { return .none }
                state.isLoading = true
                return .task(Action.districtsReceived) {
                    try await districtDataFetcher.fetchAll(festivalID: festival.id)
                }
            case .binding(\.selectedDistrict):
                userDefaultsClient.setString(state.selectedDistrict?.id, defaultDistrictKey)
                return .none
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
                state.alert = AlertFeature.error("情報の取得に失敗しました \(error.localizedDescription)")
                return .none
            case .districtsReceived(.success):
                state.isLoading = false
                return .none
            case .districtsReceived(.failure(let error)):
                state.isLoading = false
                state.alert = AlertFeature.error("情報の取得に失敗しました \(error.localizedDescription)")
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
