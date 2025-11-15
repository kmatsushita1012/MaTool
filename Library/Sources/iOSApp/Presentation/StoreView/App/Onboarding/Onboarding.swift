//
//  OnBoardingFeature.swift
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
        var festivals: [Festival]?
        var selectedFestival: Festival?
        var districts: [District]?
        var festivalErrorMessaage: String?
        var isFestivalsLoading: Bool = false
        var isDistrictsLoading: Bool = false
        var isLoading: Bool { isFestivalsLoading || isDistrictsLoading }
    }
    
    @CasePathable
    enum Action: Equatable, BindableAction {
        case binding(BindingAction<State>)
        case onAppear
        case externalGuestTapped
        case adminTapped
        case districtSelected(District)
        case festivalsReceived(Result<[Festival], APIError>)
        case districtsReceived(Result<[District], APIError>)
    }
    
    @Dependency(\.apiRepository) var apiRepository
    @Dependency(\.userDefaultsClient) var userDefaultsClient
    @Dependency(\.values.defaultFestivalKey) var defaultFestivalKey
    @Dependency(\.values.defaultDistrictKey) var defaultDistrictKey
    @Dependency(\.values.hasLaunchedBeforeKey) var hasLaunchedBeforeKey
    
    var body: some ReducerOf<OnboardingFeature> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .binding(\.selectedFestival):
                guard let festival = state.selectedFestival else {
                    state.districts = nil
                    return .none
                }
                state.isDistrictsLoading = true
                return .run { send in
                    let result = await apiRepository.getDistricts(festival.id)
                    await send(.districtsReceived(result))
                }
            case .binding:
                return .none
            case .onAppear:
                state.isFestivalsLoading = true
                return .run { send in
                    let result = await apiRepository.getFestivals()
                    await send(.festivalsReceived(result))
                }
            case .externalGuestTapped,
                .adminTapped:
                guard let festival = state.selectedFestival else {
                    state.festivalErrorMessaage = "祭典を選択してください。"
                    return .none
                }
                userDefaultsClient.setString(festival.id, defaultFestivalKey)
                userDefaultsClient.setBool(true, hasLaunchedBeforeKey)
                return .none
            case .districtSelected(let district):
                guard let festival = state.selectedFestival else {
                    state.festivalErrorMessaage = "祭典を選択してください。"
                    return .none
                }
                userDefaultsClient.setString(festival.id, defaultFestivalKey)
                if(district.festivalId != festival.id){
                    return .none
                }
                userDefaultsClient.setString(district.id, defaultDistrictKey)
                userDefaultsClient.setBool(true, hasLaunchedBeforeKey)
                return .none
            case .festivalsReceived(.success(let value)):
                state.festivals = value
                state.isFestivalsLoading = false
                return .none
            case .festivalsReceived(.failure(_)):
                state.isFestivalsLoading = false
                return .none
            case .districtsReceived(.success(let value)):
                state.districts = value
                state.isDistrictsLoading = false
                return .none
            case .districtsReceived(.failure(_)):
                state.isDistrictsLoading = false
                return .none
            }
        }
    }
}

