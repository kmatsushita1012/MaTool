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
                email: $store.email
            )
            .navigationTitle("新規作成")
            .toolbar {
                ToolbarCancelButton {
                    store.send(.cancelTapped)
                }
                ToolbarSaveButton(title: "作成", isLoading: store.isLoading) {
                    store.send(.createTapped)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .alert($store.scope(state: \.alert, action: \.alert))
        }
    }
}
