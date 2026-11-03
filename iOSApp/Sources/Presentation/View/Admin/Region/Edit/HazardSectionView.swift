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
            ToolbarDoneButton {
                store.send(.doneTapped)
            }
            if isLiquidGlassEnabled, #available(iOS 26.0, *)  {
                bottomBarAfterLiquidGlass
            } else {
                bottomBarBeforeLiquidGlass
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
    var bottomBarBeforeLiquidGlass: some ToolbarContent {
        ToolbarItemGroup(placement: .bottomBar) {
            HStack(spacing:8){
                undoButton
                redoButton
                Spacer()
                deleteButton
            }
            .padding(.horizontal, 8)
        }
    }
    
    @available(iOS 26.0, *)
    @ToolbarContentBuilder
    var bottomBarAfterLiquidGlass: some ToolbarContent {
        ToolbarItemGroup(placement: .bottomBar) {
            undoButton
            redoButton
        }
        ToolbarSpacer(.flexible ,placement: .bottomBar)
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


fileprivate struct HazardSectionEditMap: View {
    var coordinates: [Coordinate]
    @Binding var region: MKCoordinateRegion?
    var onMapLongPress: (Coordinate) -> Void
    var onSelect: (Coordinate) -> Void

    @State private var position: MapCameraPosition
    @State private var selectedIndex: Int?

    init(coordinates: [Coordinate], region: Binding<MKCoordinateRegion?>, onMapLongPress: @escaping (Coordinate) -> Void, onSelect: @escaping (Coordinate) -> Void) {
        self.coordinates = coordinates
        self._region = region
        self.onMapLongPress = onMapLongPress
        self.onSelect = onSelect
        self._position = State(initialValue: region.wrappedValue.map(MapCameraPosition.region) ?? .automatic)
    }

    var body: some View {
        MapReader { proxy in
            Map(position: $position, selection: $selectedIndex) {
                ForEach(Array(coordinates.enumerated()), id: \.offset) { index, coordinate in
                    Marker("", coordinate: coordinate.toCL()).tag(index)
                }
                MapPolyline(coordinates: coordinates.map { $0.toCL() })
                    .stroke(.blue, lineWidth: 4)
            }
            .onChange(of: selectedIndex) { _, index in
                guard let index, coordinates.indices.contains(index) else { return }
                selectedIndex = nil
                onSelect(coordinates[index])
            }
            .onMapCameraChange(frequency: .onEnd) { region = $0.region }
            .simultaneousGesture(
                LongPressGesture().sequenced(before: DragGesture(minimumDistance: 0))
                    .onEnded { value in
                        if case let .second(true, drag?) = value,
                           let coordinate = proxy.convert(drag.startLocation, from: .local) {
                            onMapLongPress(.fromCL(coordinate))
                        }
                    }
            )
        }
    }
}

