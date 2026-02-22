//
//  PublicLocationsMapView.swift
//  MaTool
//
//  Created by 松下和也 on 2025/05/04.
//

import SwiftUI
import ComposableArchitecture

struct PublicLocationsMapView: View {
    @Perception.Bindable var store: StoreOf<PublicLocationsFeature>
    @Environment(\.isLiquidGlassDisabled) var isLiquidGlassDisabled
    
    var body: some View {
        WithPerceptionTracking{
            MapView(style: .public, floats: store.floats, region: $store.mapRegion, floatTapped: { store.send(.floatTapped($0)) })
            .ignoresSafeArea(edges: .bottom)
            .safeAreaInset(edge: .bottom){
                if isLiquidGlassDisabled {
                    toolbarLayer
                }
            }
            .toolbar{
                if !isLiquidGlassDisabled, #available(iOS 26.0, *) {
                    toolbar
                }
            }
            .alert($store.scope(state: \.alert, action: \.alert))
            .sheet(item: $store.detail){ location in
                LocationView(location)
                    .presentationDetents([.fraction(0.3)])
            }
        }
    }
    
    @ViewBuilder
    var toolbarLayer: some View {
        VStack{
            Spacer()
            HStack{
                Spacer()
                buttons
                    .padding()
            }
        }
    }
    
    @ViewBuilder
    var buttons: some View {
        HStack {
            FloatingIconButton(icon: "location.fill"){
                store.send(.userFocusTapped)
            }
            Divider()
            FloatingIconMenu(
                icon: "mappin.and.ellipse",
                items: store.floats,
                itemLabel: { Text( $0.district.name ) }
            ){
                store.send(.floatFocusSelected($0))
            }
            Divider()
            FloatingIconButton(icon: "arrow.clockwise"){
                store.send(.reloadTapped)
            }
        }
        .padding(8)
        .fixedSize()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(uiColor: .systemBackground))
                .shadow(radius: 8)
        )
    }
    
    @available(iOS 26.0, *)
    @ToolbarContentBuilder
    var toolbar: some ToolbarContent {
        ToolbarSpacer(.flexible, placement: .bottomBar)
        ToolbarItemGroup(placement: .bottomBar) {
            Button(systemImage: "location.fill"){
                store.send(.userFocusTapped)
            }
            Menu {
                ForEach(store.floats, id: \.self) { item in
                    Button(item.district.name){
                        store.send(.floatFocusSelected(item))
                    }
                }
            } label: {
                Image(systemName: "mappin.and.ellipse")
            }
            Button(systemImage: "arrow.clockwise"){
                store.send(.reloadTapped)
            }
        }
    }
}
