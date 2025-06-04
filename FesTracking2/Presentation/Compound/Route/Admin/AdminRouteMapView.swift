//
//  RouteMapAdminPage.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/04/08.
//

import SwiftUI
import MapKit
import ComposableArchitecture

struct AdminRouteMapView: View{
    @Bindable var store: StoreOf<AdminRouteMapFeature>
    @State private var selectedDetent: PresentationDetent = .large
    
    var body: some View{
            // 背景のMap
        NavigationStack{
            ZStack {
                AdminRouteMap(
                    points: store.route.points,
                    segments: store.route.segments,
                    onMapLongPress: { coordinate in store.send(.mapLongPressed(coordinate))},
                    pointTapped: { point in store.send(.annotationTapped(point))},
                    polylineTapped: { segment in store.send(.polylineTapped(segment))},
                    region: $store.region
                )
                .edgesIgnoringSafeArea(.bottom)
                VStack {
                    HStack {
                        Spacer()
                        RouteButton(
                            systemImageName: "arrow.uturn.left",
                            action:{store.send(.undoTapped)}
                        )
                        .frame(width: 64, height: 64)
                        .padding(4)
                        RouteButton(
                            systemImageName: "arrow.uturn.right",
                            action:{store.send(.redoTapped)}
                        )
                        .frame(width: 64, height: 64)
                        .padding(4)
                    }
                    Spacer()
                }
            }.sheet(store: store.scope(state: \.$pointAdmin, action: \.pointAdmin)) { store in
                AdminPointView(store: store)
                    .presentationDetents([.fraction(0.3), .large], selection: $selectedDetent)
                    .interactiveDismissDisabled(true)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("キャンセル") {
                        store.send(.cancelTapped)
                    }
                    .padding(8)
                }
                ToolbarItem(placement: .principal) {
                    Text("ルート編集")
                        .bold()
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button{
                        store.send(.doneTapped)
                    } label: {
                        Text("完了")
                            .bold()
                    }
                    .padding(8)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
