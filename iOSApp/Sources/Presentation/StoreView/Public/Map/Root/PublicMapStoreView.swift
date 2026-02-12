//
//  DistrictSummaryView.swift
//  MaTool
//
//  Created by 松下和也 on 2025/03/19.
//

import ComposableArchitecture
import SwiftUI
import NavigationSwipeControl

struct PublicMapStoreView: View {
    @Perception.Bindable var store: StoreOf<PublicMap>
    
    var body: some View {
        WithPerceptionTracking{
            VStack(spacing: 0){
                picker()
                if let routeStore = store.scope(state: \.destination?.route, action: \.destination.route) {
                    PublicRouteMapView(store: routeStore)
                        .id(routeStore.district.id)
                } else if let store = store.scope(state: \.destination?.locations, action: \.destination.locations) {
                    PublicLocationsMapStoreView(store: store)
                } else {
                    Spacer()
                }
            }
            .loadingOverlay(store.isLoading)
            .background(Color.map)
            .navigationTitle("地図")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(systemImage: "house"){
                        store.send(.homeTapped)
                    }
                    .foregroundColor(.black)
                }
                .hideSharedBackgroundVisibility()
            }
            .alert($store.scope(state: \.alert, action: \.alert))
            .dismissible(backButton: false)
            .onAppear{
                store.send(.onAppear)
            }
            .dismissOnChange(of: store.isDismissed)
        }
    }
    
    @ViewBuilder
    private func picker() -> some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(store.contents, id: \.self) { item in
                        WithPerceptionTracking{
                            menuButton(for: item)
                                .id(item)
                        }
                    }
                }
            }
            .background(Color.map)
            .onAppear{
                withAnimation {
                    proxy.scrollTo(store.selectedContent, anchor: .center)
                }
            }
            .onChange(of: store.selectedContent) { newValue in
                withAnimation {
                    proxy.scrollTo(store.selectedContent, anchor: .center)
                }
            }
        }
    }
    
    @ViewBuilder
    private func menuButton(for item: PublicMap.Content) -> some View {
        let isSelected = item == store.selectedContent
        
        Button(action: {
            if !isSelected {
                store.send(.contentSelected(item))
            }
        }) {
            Text(item.text)
                .foregroundColor(.primary)
                .padding(.vertical, 8)
                .padding(.horizontal, 16)
                .frame(minWidth: 48)
                .background(isSelected ? Color.white : .clear)
                .clipShape(
                    isSelected
                    ? .rect(
                        topLeadingRadius: 16,
                        bottomLeadingRadius: 0,
                        bottomTrailingRadius: 0,
                        topTrailingRadius: 16
                    )
                    : .rect()
                )
        }
    }
}
