import iOSShared
import Application
import View
//
//  FestivalInfoView.swift
//  MaTool
//
//  Created by 松下和也 on 2025/07/29.
//

import SwiftUI
import ComposableArchitecture
import MapKit
import Shared

struct FestivalInfoScreen: View {
    @Perception.Bindable var store: StoreOf<FestivalInfoFeature>
    let isDistrictLoading: Bool

    init(
        store: StoreOf<FestivalInfoFeature>,
        isDistrictLoading: Bool = false
    ) {
        self.store = store
        self.isDistrictLoading = isDistrictLoading
    }

    var body: some View {
        WithPerceptionTracking {
            FestivalInfoContentView(
                festival: store.festival,
                displayMode: $store.displayMode,
                festivalContent: { imageBottomY in
                    FestivalInfoOverviewContentView(
                        festival: store.festival,
                        imageBottomY: imageBottomY,
                        region: $store.region
                    )
                },
                districtsContent: {
                    FestivalInfoDistrictListContentView(
                        districts: store.districts,
                        isLoading: isDistrictLoading,
                        onDistrictSelected: { store.send(.districtSelected($0)) }
                    )
                }
            )
            .navigationDestination(
                item: $store.scope(state: \.destination, action: \.destination)
            ) { destination in
                switch destination.case {
                case .district(let store):
                    DistrictInfoScreen(store: store)
                }
            }
        }
    }
}
