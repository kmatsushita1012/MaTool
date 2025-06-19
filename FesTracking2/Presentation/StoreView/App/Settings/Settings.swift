//
//  Home.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/04/20.
//

import ComposableArchitecture
import Foundation

@Reducer
struct Settings {
    
    @Dependency(\.apiClient) var apiClient
    @Dependency(\.userDefaultsClient) var userDefaultsClient
    
    @ObservableState
    struct State: Equatable {
        let regions: [Region]
        var selectedRegion: Region? = nil
        var districts: [PublicDistrict] = []
        var selectedDistrict: PublicDistrict? = nil
        var isLoading: Bool = false
        var userGuide: URL = URL(string: userGuideURLString)!
        var contact: URL = URL(string: contactURLString)!
        @Presents var alert: OkAlert.State? = nil
        var isDismissEnabled: Bool {
            selectedRegion != nil
        }
    }

    @CasePathable
    enum Action: Equatable, BindableAction {
        case binding(BindingAction<State>)
        case dismissTapped
        case districtsReceived(Result<[PublicDistrict], ApiError>)
        case alert(PresentationAction<OkAlert.Action>)
    }

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
                    let result = await apiClient.getDistricts(region.id)
                    await send(.districtsReceived(result))
                }
            case .binding(\.selectedDistrict):
                userDefaultsClient.setString(state.selectedDistrict?.id, defaultDistrictKey)
                return .none
            case .binding:
                return .none
            case .dismissTapped:

                return .none
            case .districtsReceived(.success(let value)):
                state.districts = value
                state.isLoading = false
                return .none
            case .districtsReceived(.failure(let error)):
                state.isLoading = false
                state.alert = OkAlert.error("情報の取得に失敗しました \(error.localizedDescription)")
                return .none
            case .alert(.presented(.okTapped)):
                state.alert = nil
                return .none
            case .alert:
                return .none
            }
        }
    }
}
