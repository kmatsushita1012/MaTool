//
//  PublicLocationsMapStoreView.swift
//  MaTool
//
//  Created by 松下和也 on 2025/05/04.
//

import SwiftUI
import ComposableArchitecture

struct PublicLocationsMapStoreView: View {
    @Perception.Bindable var store: StoreOf<PublicLocations>
    
    var body: some View {
        WithPerceptionTracking{
            ZStack{
                PublicLocationsMap(
                    store.floatAnnotations,
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
            .sheet(item: $store.detail){ location in
                LocationView(location)
                    .presentationDetents([.fraction(0.3)])
            }
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
                items: store.floatAnnotations,
                itemLabel: { Text( $0.title ?? "" ) }
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
