//
//  DistrictSummaryView.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/03/19.
//

import ComposableArchitecture
import SwiftUI

struct RouteView: View {
    @Bindable var store: StoreOf<RouteFeature>
    
    var body: some View {
        NavigationStack{
            VStack(spacing: 0){
                if let store = store.scope(state: \.districtPicker, action: \.districtPicker) {
                    DistrictPickerView(store: store)
                    
                }
                ZStack {
                    if let store = store.scope(state: \.map?.route, action: \.map.route) {
                        RouteMapView(store: store)
                            .ignoresSafeArea(edges: .bottom)
                    } else if let store = store.scope(state: \.map?.locations, action: \.map.locations) {
                        LocationsMapView(store: store)
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
                    Text("ルート")
                        .bold()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
        
        .onAppear() {
            store.send(.onAppear("johoku"))
        }
    }
    
}


