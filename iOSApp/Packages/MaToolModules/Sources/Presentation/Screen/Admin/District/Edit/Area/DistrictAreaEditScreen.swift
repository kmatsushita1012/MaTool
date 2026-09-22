import iOSShared
import Application
import View
//
//  DistrictAreaEditScreen.swift
//  MaTool
//  Created by 松下和也 on 2025/04/16.
//

import SwiftUI
import ComposableArchitecture

@available(iOS 17.0, *)
struct DistrictAreaEditScreen: View {
    @SwiftUI.Bindable var store: StoreOf<DistrictAreaEditFeature>

    var body: some View {
        WithPerceptionTracking {
            DistrictAreaEditContentView(
                map: {
                    AdminDistrictMap(
                        coordinates: store.coordinates,
                        isShownPolygon: true,
                        region: $store.region,
                        onMapLongPress: { store.send(.mapTapped($0)) }
                    )
                },
                onUndo: { store.send(.undoTapped) },
                onCancel: { store.send(.dismissTapped) },
                onDone: { store.send(.doneTapped) }
            )
        }
    }
}
