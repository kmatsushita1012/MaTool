//
//  OnBoardingFeature.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/05/24.
//

import ComposableArchitecture
import Foundation

@Reducer
struct OnboardingFeature {
    
    @Dependency(\.apiClient) var apiClient
    @Dependency(\.userDefaultsClient) var userDefaultsClient
    
    @ObservableState
    struct State: Equatable {
        var regions: [Region]?
        var selectedRegion: Region?
        var districts: [PublicDistrict]?
        var selectedDistrict: PublicDistrict?
        var isRegionsLoading: Bool = false
        var isDistrictsLoading: Bool = false
        var isLoading: Bool {
            isRegionsLoading || isDistrictsLoading
        }
    }
    
    @CasePathable
    enum Action: Equatable, BindableAction {
        case binding(BindingAction<State>)
        case onAppear
        case okTapped
        case regionsReceived(Result<[Region], ApiError>)
        case districtsReceived(Result<[PublicDistrict], ApiError>)
    }
    
    var body: some ReducerOf<OnboardingFeature> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .binding(\.selectedRegion):
                state.isDistrictsLoading = true
                guard let region = state.selectedRegion else { return .none }
                return .run { send in
                    let result = await apiClient.getDistricts(region.id)
                    await send(.districtsReceived(result))
                }
            case .binding(_):
                return .none
            case .onAppear:
                state.isRegionsLoading = true
                return .run { send in
                    let result = await apiClient.getRegions()
                    await send(.regionsReceived(result))
                }
            case .okTapped:
                guard let region = state.selectedRegion else {
                    //TODOエラーハンドル
                    return .none
                }
                userDefaultsClient.setString(region.id, favoriteRegionPath)
                guard let district = state.selectedDistrict else {
                    userDefaultsClient.setString(nil, favoriteDistrictPath)
                    return .none
                }
                if region.id != district.regionId {
                    //TODOエラーハンドル
                    return .none
                }
                userDefaultsClient.setString(district.id, favoriteDistrictPath)
                return .none
            case .regionsReceived(.success(let value)):
                state.regions = value
                state.isRegionsLoading = false
                return .none
            case .regionsReceived(.failure(let error)):
                state.isRegionsLoading = false
                return .none
            case .districtsReceived(.success(let value)):
                state.districts = value
                state.isDistrictsLoading = false
                return .none
            case .districtsReceived(.failure(let error)):
                state.isDistrictsLoading = false
                return .none
            }
        }
    }
}

