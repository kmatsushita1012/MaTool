import iOSShared
import Application
import View
//
//  DistrictInfoView.swift
//  MaTool
//
//  Created by 松下和也 on 2025/07/29.
//

import SwiftUI
import ComposableArchitecture
import MapKit
import Shared

struct DistrictInfoScreen: View {
    @Perception.Bindable var store: StoreOf<DistrictInfoFeature>

    var body: some View {
        WithPerceptionTracking{
            DistrictInfoContentView(
                district: store.district,
                performances: store.performances,
                region: $store.region,
                isLoading: store.isLoading,
                onMapTapped: { store.send(.mapTapped) }
            )
        }
    }
}
