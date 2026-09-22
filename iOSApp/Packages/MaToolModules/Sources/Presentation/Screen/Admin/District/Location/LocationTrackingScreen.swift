import iOSShared
import Application
import View
//
//  LocationTrackingScreen.swift
//  MaTool
//  Created by 松下和也 on 2025/04/17.
//

import SwiftUI
import ComposableArchitecture

@available(iOS 17.0, *)
struct LocationTrackingScreen: View {
    @SwiftUI.Bindable var store: StoreOf<LocationTrackingFeature>

    var body: some View {
        WithPerceptionTracking {
            LocationTrackingContentView(
                isTracking: $store.isTracking,
                selectedInterval: $store.selectedInterval,
                intervals: store.intervals,
                isPickerEnabled: store.isPickerEnabled,
                history: store.history,
                map: {
                    AdminLocationMap(location: store.location)
                }
            )
            .onAppear {
                store.send(.onAppear)
            }
        }
    }
}
