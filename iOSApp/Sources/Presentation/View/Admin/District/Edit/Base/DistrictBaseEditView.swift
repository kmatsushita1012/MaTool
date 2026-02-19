//
//  DistrictBaseEditView.swift
//  MaTool
//
//  Created by 松下和也 on 2025/04/16.
//

import SwiftUI
import ComposableArchitecture
import NavigationSwipeControl

@available(iOS 17.0, *)
struct DistrictBaseEditView:View {
    @SwiftUI.Bindable var store: StoreOf<DistrictBaseEditFeature>
    
    var body: some View {
        ZStack {
            AdminDistrictMap(
                coordinates: store.coordinate.map { [$0] },
                isShownPolygon: false,
                region: $store.region,
                onMapLongPress: { coordinate in store.send(.mapTapped(coordinate))}
            )
            .edgesIgnoringSafeArea(.all)
            
            VStack {
                HStack {
                    Spacer()
                    Button(action: {
                        store.send(.clearTapped)
                    }) {
                        Image(systemName: "eraser")
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
        .dismissible(backButton: false, edgeSwipe: false)
    }
}
