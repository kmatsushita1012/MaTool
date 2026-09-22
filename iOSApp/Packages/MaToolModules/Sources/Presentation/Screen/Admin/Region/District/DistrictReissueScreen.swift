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
            DistrictReissueContentView(email: $store.email)
                .navigationTitle("アカウント再発行")
                .toolbar {
                    ToolbarCancelButton {
                        store.send(.cancelTapped)
                    }
                    ToolbarSaveButton(title: "再発行", isLoading: store.isLoading) {
                        store.send(.reissueTapped)
                    }
                }
                .navigationBarTitleDisplayMode(.inline)
                .alert($store.scope(state: \.alert, action: \.alert))
        }
    }
}
