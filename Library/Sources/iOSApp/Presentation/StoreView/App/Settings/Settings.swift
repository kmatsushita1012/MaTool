//
//  Home.swift
//  MaTool
//
//  Created by 松下和也 on 2025/04/20.
//

import ComposableArchitecture
import Foundation

@Reducer
struct Settings {
    
    @ObservableState
    struct State: Equatable {
        let isOfflineMode: Bool
        var regions: [Region] = []
        var selectedRegion: Region? = nil
        var districts: [District] = []
        var selectedDistrict: District? = nil
        var isLoading: Bool = false
        var userGuide: URL = URL(string: userGuideURLString)!
        var contact: URL = URL(string: contactURLString)!
        @Presents var alert: Alert.State? = nil
        var isDismissEnabled: Bool {
            selectedRegion != nil || isOfflineMode
        }
    }

    @CasePathable
    enum Action: Equatable, BindableAction {
        case binding(BindingAction<State>)
        case dismissTapped
        case signOutTapped
        case signOutReceived(Result<UserRole,AuthError>)
        case districtsReceived(Result<[District], APIError>)
        case alert(PresentationAction<Alert.Action>)
    }
    
    @Dependency(\.dismiss) var dismiss
    @Dependency(\.authService) var authService
    @Dependency(\.apiRepository) var apiRepository
    @Dependency(\.userDefaultsClient) var userDefaultsClient
    
    var body: some ReducerOf<Settings> {
        BindingReducer()
        Reduce{ state, action in
            switch action {
            case .binding(\.selectedRegion):
                state.districts = []
                state.selectedDistrict = nil
                userDefaultsClient.setString(state.selectedDistrict?.id, defaultDistrictKey)
                userDefaultsClient.setString(state.selectedRegion?.id, defaultRegionKey)
                guard let region = state.selectedRegion else {
                    return .none
                }
                state.isLoading = true
                return .run { send in
                    let result = await apiRepository.getDistricts(region.id)
                    await send(.districtsReceived(result))
                }
            case .binding(\.selectedDistrict):
                userDefaultsClient.setString(state.selectedDistrict?.id, defaultDistrictKey)
                return .none
            case .binding:
                return .none
            case .signOutTapped:
                return .run { send in
                    let result = await authService.signOut()
                    await send(.signOutReceived(result))
                }
            case .signOutReceived(.success):
                state.alert = Alert.success("ログアウトしました")
                return .none
            case .signOutReceived(.failure(let error)):
                state.alert = Alert.error("情報の取得に失敗しました \(error.localizedDescription)")
                return .none
            case .districtsReceived(.success(let value)):
                state.districts = value
                state.isLoading = false
                return .none
            case .districtsReceived(.failure(let error)):
                state.isLoading = false
                state.alert = Alert.error("情報の取得に失敗しました \(error.localizedDescription)")
                return .none
            case .alert:
                state.alert = nil
                return .none
            case .dismissTapped:
                return .run {_ in
                    await dismiss()
                }
            }
        }
    }
}
