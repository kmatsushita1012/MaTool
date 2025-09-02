//
//  PublicLocationsMapStoreView.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/05/04.
//

import SwiftUI
import ComposableArchitecture

struct PublicLocationsMapStoreView: View {
    @Bindable var store: StoreOf<PublicLocations>
    
    var body: some View {
        ZStack{
            PublicLocationsMap(
                items: store.locations,
                onTap: { store.send(.locationTapped($0)) },
                region: $store.mapRegion
            )
            .ignoresSafeArea(edges: .bottom)
            VStack{
                Spacer()
                HStack{
                    Spacer()
                    buttons()
                        .padding()
                }
            }
        }
        .sheet(item: $store.detail){ item in
            LocationView(item: item)
                .presentationDetents([.fraction(0.3)])
        }
    }
    
    @ViewBuilder
    func buttons() -> some View {
        HStack {
            FloatingIconButton(icon: "location.fill"){
                store.send(.userFocusTapped)
            }
            Divider()
            FloatingIconMenu(
                icon: "mappin.and.ellipse",
                items: store.locations,
                itemLabel: { Text( $0.districtName ) }
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
                .fill(Color.white)
                .shadow(radius: 8)
        )
    }
}
