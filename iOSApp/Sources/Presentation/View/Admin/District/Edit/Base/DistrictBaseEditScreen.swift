//
//  DistrictBaseEditScreen.swift
//  MaTool
//  Created by 松下和也 on 2025/04/16.
//

import SwiftUI
import ComposableArchitecture

@available(iOS 17.0, *)
struct DistrictBaseEditScreen: View {
    @SwiftUI.Bindable var store: StoreOf<DistrictBaseEditFeature>

    var body: some View {
        WithPerceptionTracking {
            DistrictBaseEditContentView(
                map: {
                    AdminDistrictMap(
                        coordinates: store.coordinate.map { [$0] },
                        isShownPolygon: false,
                        region: $store.region,
                        onMapLongPress: { store.send(.mapTapped($0)) }
                    )
                },
                onClear: { store.send(.clearTapped) }
            )
            .navigationTitle("会所位置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarCancelButton {
                    store.send(.dismissTapped)
                }
                ToolbarDoneButton {
                    store.send(.doneTapped)
                }
            }
            .toolbarBackground(.visible, for: .navigationBar)
        }
    }
}
