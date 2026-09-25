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
    @Namespace private var namespace
    
    var body: some View {
        WithPerceptionTracking{
            @Binding(store.$mapRegion) var mapRegion
            ZStack(alignment: .top) {
                MapView(style: .public, floats: store.floats, region: $mapRegion, floatTapped: { store.send(.floatTapped($0)) })

                if let toast = store.toast {
                    MapToastView(toast: toast) {
                        store.send(.toastDismissed)
                    }
                    .padding(.top, 16)
                    .transition(.opacity)
                }
            }
            .ignoresSafeArea(edges: .bottom)
            .animation(.easeInOut(duration: 0.2), value: store.toast)
            .safeAreaInset(edge: .bottom){
                if isLiquidGlassDisabled {
                    toolbarLayer
                } else if #available(iOS 26.0, *) {
                    toolbarLayerAfterLiquidGlass
                }
            }
            .onAppear {
                store.send(.onAppear)
            }
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
    @ViewBuilder
    var toolbarLayerAfterLiquidGlass: some View {
        HStack {
            Spacer()
            GlassEffectContainer(spacing: 8) {
                HStack(spacing: 8) {

                    FloatingIconButton(icon: "location.fill") {
                        store.send(.userFocusTapped)
                    }
                    .glassEffectUnion(id: "bottombar", namespace: namespace)

                    Menu {
                        ForEach(store.floats, id: \.self) { item in
                            Button(item.district.name) {
                                store.send(.floatFocusSelected(item))
                            }
                        }
                    } label: {
                        Image(systemName: "mappin.and.ellipse")
                            .font(.title2)
                            .contentShape(.rect)
                    }
                    .buttonStyle(.glass)
                    .glassEffectUnion(id: "bottombar", namespace: namespace)
                    .disabled(store.floats.isEmpty)

                    FloatingIconButton(icon: "arrow.clockwise") {
                        store.send(.reloadTapped)
                    }
                    .glassEffectUnion(id: "bottombar", namespace: namespace)
                }
            }

        }
        .padding(.horizontal)
    }
}
