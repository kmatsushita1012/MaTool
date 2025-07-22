//
//  DistrictSummaryView.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/03/19.
//

import ComposableArchitecture
import SwiftUI
import NavigationSwipeControl

struct PublicMapStoreView: View {
    @Bindable var store: StoreOf<PublicMap>
    
    var body: some View {
        VStack(spacing: 0){
            if let store = store.scope(state: \.districtPicker, action: \.districtPicker) {
                DistrictPickerView(store: store)
            }
            ZStack {
                if let store = store.scope(state: \.map?.route, action: \.map.route) {
                    PublicRouteMapStoreView(store: store)
                        .ignoresSafeArea(edges: .bottom)
                } else if let store = store.scope(state: \.map?.locations, action: \.map.locations) {
                    LocationsMapStoreView(store: store)
                        .ignoresSafeArea(edges: .bottom)
                }else {
                    Spacer()
                }
                if let store = store.scope(state: \.routePicker, action: \.routePicker) {
                    VStack{
                        RoutePickerView(store: store)
                        Spacer()
                    }
                }
            }
        }
        .ignoresSafeArea(edges: .bottom)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(action: {
                    store.send(.homeTapped)
                }) {
                    Image(systemName: "house")
                        .foregroundColor(.black)
                }
                .padding(.horizontal, 8)
            }
            ToolbarItem(placement: .principal) {
                Text("地図")
                    .bold()
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .dismissible(backButton: false)
        .onAppear() {
            //TODO
            store.send(.onAppear)
        }
    }
    
}


