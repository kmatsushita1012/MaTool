import iOSShared
import Application
import View
//
//  OnboardingScreen.swift
//  MaTool
//  Created by 松下和也 on 2025/05/24.
//

import SwiftUI
import ComposableArchitecture
import Shared

struct OnboardingScreen: View {
    @Perception.Bindable var store: StoreOf<OnboardingFeature>

    var body: some View {
        WithPerceptionTracking {
            OnboardingContentView(
                festivals: store.festivals,
                selectedFestival: $store.selectedFestival,
                festivalErrorMessage: store.festivalErrorMessaage,
                districts: store.districts,
                isLoading: store.isLoading,
                onDistrictSelected: { store.send(.districtSelected($0)) },
                onExternalGuestTapped: { store.send(.externalGuestTapped) }
            )
        }
    }
}
