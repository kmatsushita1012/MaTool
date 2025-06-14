//
//  RouteMapAdminPage.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/04/08.
//

import SwiftUI
import MapKit
import ComposableArchitecture

struct AdminRouteMapStoreView: View{
    @Bindable var store: StoreOf<AdminRouteMap>
    @State private var selectedDetent: PresentationDetent = .large
    
    var body: some View{
            // 背景のMap
        NavigationStack{
            ZStack {
                AdminRouteMapView(
                    points: store.route.points,
                    segments: store.route.segments,
                    onMapLongPress: { coordinate in store.send(.mapLongPressed(coordinate))},
                    pointTapped: { point in store.send(.annotationTapped(point))},
                    polylineTapped: { segment in store.send(.polylineTapped(segment))},
                    region: $store.region
                )
                .edgesIgnoringSafeArea(.bottom)
                VStack {
                    HStack(spacing: 16) {
                        Text(store.operation.text)
                            .font(.title3)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.black.opacity(0.5))
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        Button(action: {
                            store.send(.undoTapped)
                        }) {
                            Image(systemName: "arrow.uturn.backward")
                                .font(.title2)
                                .foregroundColor(.white)
                                .padding(8)
                                .background(Color.black.opacity(0.5))
                                .clipShape(Circle())
                        }
                        .disabled(!store.canUndo)
                        Button(action: {
                            store.send(.redoTapped)
                        }) {
                            Image(systemName: "arrow.uturn.forward")
                                .font(.title2)
                                .foregroundColor(.white)
                                .padding(8)
                                .background(Color.black.opacity(0.5))
                                .clipShape(Circle())
                        }
                        .disabled(!store.canRedo)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .topTrailing)
                    Spacer()
                }
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
            .sheet(item: $store.scope(state: \.destination?.point, action: \.destination.point)) { store in
                AdminPointView(store: store)
                    .presentationDetents([.fraction(0.3), .large], selection: $selectedDetent)
                    .interactiveDismissDisabled(true)
            }
//            .fullScreenCover(item: $store.scope(state: \.destination?.segment, action: \.destination.segment)) { store in
//                AdminSegmentView(store: store)
//                    .presentationDetents([.fraction(0.3), .large], selection: $selectedDetent)
//                    .interactiveDismissDisabled(true)
//            }
        }
    }
}
extension AdminRouteMap.Operation {
    var text: String {
        switch self {
        case .add:
            return "長押しで地点を追加"
        case .insert:
            return "長押しで地点を挿入"
        case .move:
            return "長押しで地点を移動"
        }
    }
}
