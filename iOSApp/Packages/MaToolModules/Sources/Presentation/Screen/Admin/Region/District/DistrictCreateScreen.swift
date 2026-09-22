import iOSShared
import Application
import View
//
//  DistrictCreateScreen.swift
//  MaTool
//  Created by 松下和也 on 2025/05/12.
//

import SwiftUI
import ComposableArchitecture

@available(iOS 17.0, *)
struct DistrictCreateScreen: View {
    @SwiftUI.Bindable var store: StoreOf<DistrictCreateFeature>

    var body: some View {
        WithPerceptionTracking {
            DistrictCreateContentView(
                name: $store.name,
                email: $store.email,
                isLoading: store.isLoading,
                onCancel: { store.send(.cancelTapped) },
                onCreate: { store.send(.createTapped) }
            )
            .alert($store.scope(state: \.alert, action: \.alert))
        }
    }
}
