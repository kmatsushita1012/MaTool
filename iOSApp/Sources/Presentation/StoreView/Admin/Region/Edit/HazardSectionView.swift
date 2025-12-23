//
//  HazardSectionView.swift
//  MaTool
//
//  Created by 松下和也 on 2025/12/09.
//

import SwiftUI
import ComposableArchitecture
import UIKit
import MapKit
import Shared

@available(iOS 17.0, *)
struct HazardSectionView: View {
    
    @SwiftUI.Bindable var store: StoreOf<HazardSectionFeature>
    @Dependency(\.values.isLiquidGlassEnabled) var isLiquidGlassEnabled
    
    var body: some View {
        Group {
            info
        }
        .background {
            Color(UIColor.secondarySystemBackground)
                .ignoresSafeArea(.container, edges: [.bottom, .top])
        }
        .navigationTitle("要注意区間")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if isLiquidGlassEnabled, #available(iOS 26.0, *)  {
                toolbarAfterLiquidGlass
            } else {
                toolbarBeforeLiquidGlass
            }
        }
        .alert($store.scope(state: \.alert, action: \.alert))
        .confirmationDialog(item: $store.selectedPin, title: {_ in Text("地点を編集")}) { item in
            Button("この地点の前に新しい地点を挿入") { store.send(.insertBeforeTapped(item)) }
            Button("この地点の後に新しい地点を挿入") { store.send(.insertAfterTapped(item)) }
            Button("削除", role: .destructive) { store.send(.removeTapped(item)) }
            Button("キャンセル") { store.send(.menuClosed) }
        }
    }
    
    
    @ViewBuilder
    var info: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading){
                Text("タイトル")
                    .font(.headline)
                    .foregroundStyle(.gray)
                TextField(
                    "注釈の内容（例: 斜度 5°）",
                    text: $store.item.title
                )
                .padding()
                .background(.background)
                .clipShape(.capsule)
            }
            
            HazardSectionEditMap(
                coordinates: store.item.coordinates,
                region: $store.mapRegion,
                onMapLongPress: { store.send(.mapLongPressed($0)) },
                onSelect: { store.send(.pinSelected($0)) }
            )
            .roundedRect()
        }
        .padding()
    }
    
    @ToolbarContentBuilder
    var toolbarBeforeLiquidGlass: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Button("完了") {
                store.send(.doneTapped)
            }
            .tint(.accent)
        }
        ToolbarItemGroup(placement: .bottomBar) {
            undoButton
            redoButton
            clearButton
            deleteButton
        }
    }
    
    @available(iOS 26.0, *)
    @ToolbarContentBuilder
    var toolbarAfterLiquidGlass: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Button("完了", systemImage: "checkmark") {
                store.send(.doneTapped)
            }
            .tint(.accent)
        }
        ToolbarItemGroup(placement: .bottomBar) {
            undoButton
            redoButton
        }
        ToolbarSpacer(.flexible ,placement: .bottomBar)
        ToolbarItem(placement: .bottomBar) {
            clearButton
        }
        ToolbarSpacer(.fixed, placement: .bottomBar)
        ToolbarItem(placement: .bottomBar) {
            deleteButton
        }
    }
    
    @ViewBuilder
    var undoButton: some View {
        Button("戻る", systemImage: "arrow.uturn.backward") {
            store.send(.undoTapped)
        }
        .disabled(!store.manager.canUndo)
    }
    
    @ViewBuilder
    var redoButton: some View {
        Button("やり直す", systemImage: "arrow.uturn.forward") {
            store.send(.redoTapped)
        }
        .disabled(!store.manager.canRedo)
    }
    
    @ViewBuilder
    var clearButton: some View {
        Button("クリア", systemImage: "arrow.counterclockwise", role: .destructive) {
            store.send(.clearTapped)
        }
        .tint(.red)
    }
    
    @ViewBuilder
    var deleteButton: some View {
        Button("削除", systemImage: "trash", role: .destructive) {
            store.send(.deleteTapped)
        }
        .tint(.red)
    }
}


fileprivate struct HazardSectionEditMap: MapViewRepresentable {
    var coordinates: [Coordinate]
    @Binding var region: MKCoordinateRegion?
    var onMapLongPress: (Coordinate) -> Void
    var onSelect: (Coordinate) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        
        let longPress = UILongPressGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleLongPress(_:)))
        mapView.addGestureRecognizer(longPress)
        
        if let region = region {
            mapView.setRegion(region, animated: false)
        }
        
        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        update(coordinates: coordinates, in: mapView)
        mapView.removeOverlays(mapView.overlays)
        let polyline = PathPolyline(coordinates)
        mapView.addOverlay(polyline)
    }

    class Coordinator: MapCoordinator<HazardSectionEditMap> {

        @objc func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
            guard gesture.state == .began,
                  let mapView = gesture.view as? MKMapView else { return }
            let location = gesture.location(in: mapView)
            let coordinate = mapView.convert(location, toCoordinateFrom: mapView)
            parent.onMapLongPress(Coordinate.fromCL(coordinate))
        }
        
        
        override func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
            super.mapView(mapView, didSelect: view)
            guard let coordinate = view.annotation?.coordinate else { return }
            parent.onSelect(.fromCL(coordinate))
        }
    }
}

