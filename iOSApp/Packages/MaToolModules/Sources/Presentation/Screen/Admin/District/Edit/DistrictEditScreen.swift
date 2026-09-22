import iOSShared
import Application
import View
//
//  DistrictEditScreen.swift
//  MaTool
//  Created by 松下和也 on 2025/04/16.
//

import SwiftUI
import ComposableArchitecture
import Shared

@available(iOS 17.0, *)
struct DistrictEditScreen: View {
    @SwiftUI.Bindable var store: StoreOf<DistrictEditFeature>

    var body: some View {
        WithPerceptionTracking {
            DistrictEditContentView(
                name: $store.district.name,
                description: $store.district.description.nonOptional,
                visibility: $store.district.visibility,
                performances: store.performances,
                isLoading: store.isLoading,
                onBaseTapped: { store.send(.baseTapped) },
                onAreaTapped: { store.send(.areaTapped) },
                onPerformanceTapped: { store.send(.performanceEditTapped($0)) },
                onAddPerformanceTapped: { store.send(.performanceAddTapped) },
                onCancel: { store.send(.cancelTapped) },
                onSave: { store.send(.saveTapped) }
            )
            .fullScreenCover(item: $store.scope(state: \.destination, action: \.destination)) { destination in
                switch destination.case {
                case .base(let store):
                    DistrictBaseEditScreen(store: store)
                case .area(let store):
                    DistrictAreaEditScreen(store: store)
                case .performance(let store):
                    PerformanceEditScreen(store: store)
                }
            }
            .alert($store.scope(state: \.alert, action: \.alert))
        }
    }
}
