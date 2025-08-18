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
            picker()
            if let store = store.scope(state: \.destination?.route, action: \.destination.route) {
                PublicRouteMapStoreView(store: store)
                    .ignoresSafeArea(edges: .bottom)
            } else if let store = store.scope(state: \.destination?.locations, action: \.destination.locations) {
                PublicLocationsMapStoreView(store: store)
                    .ignoresSafeArea(edges: .bottom)
            } else {
                Spacer()
            }
        }
        .background(Color.map)
        .navigationTitle("地図")
        .navigationBarTitleDisplayMode(.inline)
        .ignoresSafeArea(edges: .bottom)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    store.send(.homeTapped)
                }) {
                    Image(systemName: "house")
                        .foregroundColor(.black)
                }
                .padding(.horizontal, 8)
            }
        }
        .alert($store.scope(state: \.alert, action: \.alert))
        .dismissible(backButton: false)
        .onAppear{
            store.send(.onAppear)
        }
    }
    
    @ViewBuilder
    private func picker() -> some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(store.contents, id: \.self) { item in
                        menuButton(for: item)
                            .id(item)
                    }
                }
            }
            .background(Color.map)
            .onAppear{
                withAnimation {
                    proxy.scrollTo(store.selectedContent, anchor: .center)
                }
            }
            .onChange(of: store.selectedContent) {
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
