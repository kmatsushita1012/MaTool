//
//  RouteMapAdminPage.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/04/08.
//

import SwiftUI
import MapKit
import ComposableArchitecture

struct RouteMapAdminView: View{
    let store: StoreOf<RouteMapAdminFeature>
    @State private var selectedDetent: PresentationDetent = .large
    
    var body: some View{
            // 背景のMap
        ZStack {
            RouteAdminMapView(
                annotations: store.route.points,
                segments: store.route.segments,
                onMapLongPress: { coordinate in store.send(.mapLongPressed(coordinate))},
                onAnnotationTap: { point in store.send(.annotationTapped(point))},
                onPolylineTap: { segment in store.send(.polylineTapped(segment))}
            )
            .edgesIgnoringSafeArea(.all)
            VStack {
                HStack {
                    Spacer()
                    RouteButton(systemImageName: "arrow.uturn.left", action:{store.send(.undoButtonTapped)}).padding(4)
                    RouteButton(systemImageName: "arrow.uturn.right",action:{store.send(.redoButtonTapped)}).padding(4)
                    RouteButton(systemImageName: "checkmark",action:{store.send(.doneButtonTapped)}).padding(4)
                }
                Spacer()
            }
        }.sheet(store: store.scope(state: \.$pointAdmin, action: \.pointAdmin)) { store in
            PointAdminView(store: store)
                .presentationDetents([.fraction(0.3), .large], selection: $selectedDetent)
                .interactiveDismissDisabled(true)
        }
    }
}

//#Preview {
//    RouteMapAdminView(store:
//        Store(initialState:
//                RouteMapAdminFeature.State(route:Route.sample),
//          reducer:
//                { RouteMapAdminFeature() }
//         )
//    )
//}
