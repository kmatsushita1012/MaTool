import iOSShared
import Application
import View
//
//  DistrictReissueScreen.swift
//  MaTool
//  Created by Codex on 2026/03/28.
//

import SwiftUI
import ComposableArchitecture

@available(iOS 17.0, *)
struct DistrictReissueScreen: View {
    @SwiftUI.Bindable var store: StoreOf<DistrictReissueFeature>

    var body: some View {
        WithPerceptionTracking {
            DistrictReissueContentView(
                email: $store.email,
                isLoading: store.isLoading,
                onCancel: { store.send(.cancelTapped) },
                onReissue: { store.send(.reissueTapped) }
            )
                .alert($store.scope(state: \.alert, action: \.alert))
        }
    }
}
