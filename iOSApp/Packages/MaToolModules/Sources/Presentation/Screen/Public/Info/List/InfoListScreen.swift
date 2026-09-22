import iOSShared
import Application
import View
//
//  InfoListView.swift
//  MaTool
//
//  Created by 松下和也 on 2025/05/08.
//

import SwiftUI
import ComposableArchitecture
import Shared

struct InfoListScreen: View {
    @Perception.Bindable var store: StoreOf<InfoListFeature>

    var body: some View {
        WithPerceptionTracking{
            NavigationStack {
                InfoListContentView(
                    festivals: store.festivals,
                    isLinked: store.publicSelection.isLinked,
                    isFestivalListLoading: store.isFestivalListLoading,
                    onFestivalSelected: { store.send(.festivalSelected($0)) }
                )
                .navigationDestination(item: $store.scope(state: \.destination, action: \.destination)) { destination in
                    switch destination.case {
                    case .festival(let store):
                        FestivalInfoScreen(store: store, isDistrictLoading: self.store.isLoading)
                    }
                }
                .alert($store.scope(state: \.alert, action: \.alert))
            }
        }
    }
}
