//
//  AdminRouteExportView.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/05/08.
//

import SwiftUI
import ComposableArchitecture
import MapKit
import UniformTypeIdentifiers
import NavigationSwipeControl

struct AdminRouteExportView: View{
    @Bindable var store: StoreOf<AdminRouteExport>
    
    var body: some View{
        // 背景のMap
        ZStack {
            AdminRouteExportMapView(
                points: store.points,
                segments: store.segments,
                region: $store.region,
                size: $store.mapViewSize
            )
            .ignoresSafeArea(edges: .bottom)
        }
        .navigationTitle(store.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button(action: {
                    store.send(.partialTapped)
                }) {
                    Image(systemName: "camera")
                        .imageScale(.large) // 大きさ調整（optional）
                }
                Button(action: {
                    store.send(.wholeTapped)
                }) {
                    Image(systemName: "point.topright.arrow.triangle.backward.to.point.bottomleft.scurvepath")
                        .imageScale(.large)
                }
            }
        }
        .sheet(isPresented: $store.isWholePresented){
            if let pdf = store.wholePDF{
                ShareSheet([pdf])
            }
        }
        .sheet(isPresented: $store.isPartialPresented){
            if let pdf = store.partialPDF{
                ShareSheet([pdf])
            }
        }
        .onAppear{
            store.send(.onAppear)
        }
    }
}

