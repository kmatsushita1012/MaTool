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
                region: $store.region
            )
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        store.send(.mapTapped)
                    } label: {
                        Label("現在地とルート", systemImage: "paperplane.fill")
                    }
                    .overlay {
                        if store.isLoading {
                            ProgressView()
                        }
                    }
                    .disabled(store.isLoading)
                }
            }
        }
    }
}
