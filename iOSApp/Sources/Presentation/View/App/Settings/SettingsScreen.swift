//
//  SettingsView.swift
//  MaTool
//
//  Created by 松下和也 on 2025/04/21.
//

import ComposableArchitecture
import SwiftUI
import Shared

struct SettingsScreen: View {
    @Perception.Bindable var store: StoreOf<SettingsFeature>

    var body: some View {
        WithPerceptionTracking{
            SettingsContentView(
                festivals: store.festivals,
                selectedFestival: $store.selectedFestival,
                districts: store.districts,
                selectedDistrict: $store.selectedDistrict,
                isMapInfoLinked: $store.isMapInfoLinked,
                isLoading: store.isLoading,
                userGuide: store.userGuide,
                contact: store.contact,
                version: AppStatusClient.getCurrentVersion(),
                onLogin: { store.send(.loginTapped) }
            )
            .alert($store.scope(state: \.alert, action: \.alert))
            .navigationDestination(item: $store.scope(state: \.destination, action: \.destination)) { destination in
                switch destination.case {
                case .login(let store):
                    if #available(iOS 17.0, *) {
                        LoginScreen(store: store)
                    } else {
                        EmptyView()
                    }
                }
            }
        }
    }
}
