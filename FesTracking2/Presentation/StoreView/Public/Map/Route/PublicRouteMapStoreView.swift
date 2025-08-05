//
//  PublicRouteMapStoreView.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/05/03.
//

import SwiftUI
import ComposableArchitecture

struct PublicRouteMapStoreView: View {
    @Bindable var store: StoreOf<PublicRoute>
    
    var body: some View {
        ZStack{
            VStack{
                menu()
                Spacer()
            }
            PublicRouteMap(
                points: store.points,
                segments: store.segments,
                location: store.location,
                pointTapped: { store.send(.pointTapped($0))},
                locationTapped: { store.send(.locationTapped) },
                region: $store.mapRegion
            )
            .sheet(item: $store.detail) { detail in
                switch detail{
                case .point(let item):
                    PointView(item: item)
                        .presentationDetents([.fraction(0.3)])
                case .location(let item):
                    LocationView(item: item)
                        .presentationDetents([.fraction(0.3)])
                }
                
            }
        }
    }
    
    @ViewBuilder
    func menu()->some View {
        VStack(spacing: 8)  {
            if let selected = store.selectedItem {
                ToggleSelectedItem(title: selected.text(format:"m/d T"), isExpanded: $store.isMenuExpanded)
                    .padding(8)
                    .background(.white)
                    .cornerRadius(8)
                    .shadow(radius: 3)
            }
            if store.isMenuExpanded,
               let others = store.others{
                ForEach(others) { route in
                    ToggleOptionItem(
                        title: route.text(format:"m/d T"),
                        onTap: { store.send(.itemSelected(route)) }
                    )
                        .padding(8)
                        .background(Color(UIColor.systemGray5))
                        .cornerRadius(8)
                        .shadow(radius: 3)
                }
            }
        }
    }
}
