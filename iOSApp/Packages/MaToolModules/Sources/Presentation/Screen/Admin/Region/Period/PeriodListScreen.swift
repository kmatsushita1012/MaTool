import iOSShared
import Application
import View
//
//  PeriodListScreen.swift
//  MaTool
//  Created by 松下和也 on 2025/12/08.
//

import SwiftUI
import ComposableArchitecture

@available(iOS 17.0, *)
struct PeriodListScreen: View {
    @SwiftUI.Bindable var store: StoreOf<PeriodListFeature>

    var body: some View {
        WithPerceptionTracking {
            PeriodListContentView(
                latests: store.latests,
                archives: store.archives,
                isLoading: store.isLoading,
                yearOptions: store.yearOptions,
                createYear: store.createYear,
                onPeriodTapped: { store.send(.periodTapped($0)) },
                onArchiveTapped: { store.send(.archiveTapped($0)) },
                onCreate: { store.send(.periodCreateTapped) },
                onBatchCreate: { store.send(.batchCreateTapped($0)) }
            )
            .fullScreenCover(item: $store.scope(state: \.editDestination, action: \.editDestination)) { destination in
                switch destination.case {
                case .period(let store):
                    PeriodEditScreen(store: store)
                }
            }
            .navigationDestination(item: $store.scope(state: \.destination, action: \.destination)) { destination in
                switch destination.case {
                case .archives(let store):
                    PeriodArchivesScreen(store: store)
                }
            }
            .alert($store.scope(state: \.alert, action: \.alert))
        }
    }
}
