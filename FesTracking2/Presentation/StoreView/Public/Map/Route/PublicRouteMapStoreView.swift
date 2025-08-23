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
            PublicRouteMap(
                points: store.points,
                segments: store.segments,
                location: store.location,
                pointTapped: { store.send(.pointTapped($0))},
                locationTapped: { store.send(.locationTapped) },
                region: $store.mapRegion
            )
            VStack{
                Spacer()
                HStack{
                    Spacer()
                    buttons()
                        .padding()
                }
            }
            VStack{
                menu()
                    .padding()
                Spacer()
            }
            .tapOutside(isShown: $store.isMenuExpanded)
        }
        .sheet(item: $store.detail) { detail in
            switch detail{
            case .point(let item):
                PointView(item: item)
                    .presentationDetents([.fraction(0.3), .medium, .large])
            case .location(let item):
                LocationView(item: item)
                    .presentationDetents([.fraction(0.3), .medium, .large])
            }
            
        }
    }
    
    @ViewBuilder
    func menu()-> some View {
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
    
    @ViewBuilder
    func buttons() -> some View {
        HStack {
            FloatingIconButton(icon: "location.fill"){
                store.send(.userFocusTapped)
            }
            Divider()
            FloatingIconButton(icon: "mappin.and.ellipse"){
                store.send(.floatFocusTapped)
            }
            Divider()
            FloatingIconButton(icon: "point.bottomleft.forward.to.arrow.triangle.scurvepath.fill"){
                
            }
            .disabled(true)
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

