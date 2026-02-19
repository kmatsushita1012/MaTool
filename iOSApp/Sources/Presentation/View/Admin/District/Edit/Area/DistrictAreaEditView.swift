//
//  DistrictAreaEditView.swift
//  MaTool
//
//  Created by 松下和也 on 2025/04/16.
//

import SwiftUI
import ComposableArchitecture
import NavigationSwipeControl

@available(iOS 17.0, *)
struct DistrictAreaEditView:View {
    @SwiftUI.Bindable var store: StoreOf<DistrictAreaEditFeature>
    
    var body: some View {
        ZStack {
            AdminDistrictMap(
                coordinates: store.coordinates,
                isShownPolygon: true,
                region: $store.region,
                onMapLongPress: { coordinate in store.send(.mapTapped(coordinate))}
            )
            .edgesIgnoringSafeArea(.all)
            VStack {
                HStack {
                    Spacer()
                    Button(action: {
                        store.send(.undoTapped)
                    }) {
                        Image(systemName: "arrow.uturn.backward")
                            .font(.title2)
                            .padding(12)
                            .background(Color(.systemBackground).opacity(0.8))
                            .clipShape(Circle())
                    }
                    .padding()
                }
                Spacer()
            }
        }
        .navigationTitle("町域")
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
        .dismissible(backButton: false, edgeSwipe: false)
    }
    
}
