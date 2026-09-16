//
//  FestivalInfoFeature.swift
//  MaTool
//
//  Created by 松下和也 on 2025/07/27.
//

import ComposableArchitecture
import MapKit
import Shared
import SQLiteData

@Reducer
struct FestivalInfoFeature {

    enum DisplayMode: String, CaseIterable, Equatable {
        case festival = "祭紹介"
        case districts = "町一覧"
    }

    @Reducer
    enum Destination {
        case district(DistrictInfoFeature)
    }

    @ObservableState
    struct State: Equatable {
        let festival: Festival
        @FetchAll var districts: [District]
        var selectedDistrictID: District.ID?
        var displayMode: DisplayMode = .festival
        var region: MKCoordinateRegion?
        var isLoading: Bool = false
        @Presents var destination: Destination.State? = nil
    }
    
    @CasePathable
    enum Action: Equatable, BindableAction {
        case binding(BindingAction<State>)
        case districtSelected(District?)
        case mapTapped
        case destination(PresentationAction<Destination.Action>)
    }
    
    var body: some ReducerOf<FestivalInfoFeature> {
        BindingReducer()
        Reduce{ state,action in
            switch action {
            case .binding:
                return .none
            case .districtSelected(let district):
                state.selectedDistrictID = district?.id
                state.destination = district.map { .district(DistrictInfoFeature.State($0)) }
                return .none
            case .mapTapped:
                return .none
            case .destination:
                return .none
            }
        }
        .ifLet(\.$destination, action: \.destination)
    }
}

extension FestivalInfoFeature.State {
    init(item: Festival, district: District? = nil) {
        self.festival = item
        self._districts = FetchAll(festivalId: item.id)
        self.selectedDistrictID = district?.id
        self.region = makeRegion(origin: item.base, spanDelta: spanDelta)
        self.destination = district.map { .district(DistrictInfoFeature.State($0)) }
    }
}

extension FestivalInfoFeature.Destination.State: Equatable {}
extension FestivalInfoFeature.Destination.Action: Equatable {}
