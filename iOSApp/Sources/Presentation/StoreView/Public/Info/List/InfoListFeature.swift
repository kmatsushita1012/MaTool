//
//  InfoListFeature.swift
//  MaTool
//
//  Created by 松下和也 on 2025/05/08.
//

import ComposableArchitecture
import Shared
import SQLiteData

@Reducer
struct InfoListFeature {
    
    @Reducer
    enum Destination{
        case festival(FestivalInfo)
        case district(DistrictInfo)
    }
    
    @ObservableState
    struct State: Equatable {
        @FetchOne var festival: Festival
        @FetchAll private var rawDistricts: [District]
        var districts: [District] { rawDistricts.sorted() }
        var isDismissed: Bool = false
        @Presents var destination: Destination.State? = nil
        @Presents var alert: Alert.State? = nil
        var isLoading: Bool = false
        
        init(festival: Festival) {
            self._festival = FetchOne(wrappedValue: festival)
            self._rawDistricts = FetchAll(District.where{ $0.festivalId == festival.id })
        }
    }
    
    @CasePathable
    enum Action: Equatable {
        case festivalTapped
        case districtTapped(District)
        case homeTapped
        case districtPrepared(District)
        case errorCaught(APIError)
        case destination(PresentationAction<Destination.Action>)
        case alert(PresentationAction<Alert.Action>)
    }
    
    @Dependency(DistrictDataFetcherKey.self) var dataFetcher
    @Dependency(\.dismiss) var dismiss
    
    var body: some ReducerOf<InfoListFeature> {
        Reduce { state,action in
            switch action {
            case .festivalTapped:
                state.destination = .festival(FestivalInfo.State(item: state.festival))
                return .none
            case .districtTapped(let district):
                state.isLoading = true
                return .run{ send in
                    let result = await task{ try await dataFetcher.fetch(districtID: district.id) }
                    switch result {
                    case .success:
                        await send(.districtPrepared(district))
                    case .failure(let error):
                        await send(.errorCaught(error))
                    }
                }
            case .homeTapped:
                if #available(iOS 17.0, *) {
                    return .run { _ in
                        await dismiss()
                    }
                } else {
                    state.isDismissed = true
                    return .none
                }
            case .districtPrepared(let district):
                state.destination = .district(DistrictInfo.State(district))
                state.isLoading = false
                return .none
            case .errorCaught(let error):
                state.alert = Alert.error(error.localizedDescription)
                state.isLoading = false
                return .none
            case .destination:
                return .none
            case .alert:
                return .none
            }
        }
        .ifLet(\.$destination, action: \.destination)
        .ifLet(\.$alert, action: \.alert)
    }
}

extension InfoListFeature.Destination.State: Equatable {}
extension InfoListFeature.Destination.Action: Equatable {}
