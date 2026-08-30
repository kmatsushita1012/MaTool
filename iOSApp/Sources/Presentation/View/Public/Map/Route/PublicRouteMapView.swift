//
//  PublicRouteMapView.swift
//  MaTool
//
//  Created by 松下和也 on 2025/05/03.
//

import SwiftUI
import ComposableArchitecture
import MapKit

struct PublicRouteMapView: View {
    @Perception.Bindable var store: StoreOf<PublicRouteFeature>
    @StateObject var replayController: ReplayController
    
    init(store: StoreOf<PublicRouteFeature>) {
        self.store = store
        _replayController = StateObject(
            wrappedValue: ReplayController(
                name: store.district.name,
                stepDistance: 10,
                interval: 0.1,
                onEnd: { store.send(.replayEnded) }
            )
        )
    }
    
    var floatAnnotation: FloatAnnotation? {
        if store.replay.isRunning {
            replayController.annotation
        } else if let float = store.float  {
            FloatCurrentAnnotation(float)
        } else {
            nil
        }
    }
    
    var body: some View {
        WithPerceptionTracking{
            @Binding(store.$mapRegion) var mapRegion
            mapView(region: $mapRegion)
            .alert($store.scope(state: \.alert, action: \.alert))
            .sheet(item: $store.detail) { detail in
                switch detail{
                case .point(let item):
                    PointView(item)
                        .presentationDetents([.fraction(0.3), .medium, .large])
                case .location(let item):
                    LocationView(item)
                        .presentationDetents([.fraction(0.3), .medium, .large])
                }
            }
            .onAppear{ updateReplay() }
            .onChange(of: store.selected) { _ in updateReplay() }
            .onChange(of: store.replay) { _ in updateReplay() }
        }
    }

    @ViewBuilder
    private func mapView(region: Binding<MKCoordinateRegion>) -> some View {
        let map = MapView(
                style: .public,
                points: store.points,
                floatAnnotation: floatAnnotation,
                region: region,
                pointTapped: { store.send(.pointTapped($0))},
                floatTapped: { store.send(.locationTapped($0)) }
            )
            .equatable()
            .ignoresSafeArea()

        if #available(iOS 26.0, *) {
            map
                .scrollEdgeEffectStyle(.soft, for: .top)
                .safeAreaInset(edge: .bottom, spacing: 0) {
                MapRouteBottomControlsView(store: store)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.horizontal, MapGlassControlVariant.toolbar.edgeSpacing)
                    .padding(.bottom, 8)
                }
        } else {
            map.safeAreaInset(edge: .bottom, spacing: 0) {
                MapRouteBottomControlsView(store: store)
                    .padding(.bottom, 72)
            }
        }
    }

}

extension PublicRouteMapView {
    func updateReplay() {
        switch store.replay {
        case .initial:
            replayController.prepare(coordinates: store.points.map{ $0.coordinate })
        case .start:
            replayController.start()
        case let .seek(progress):
            replayController.seek(to: progress)
        case .stop:
            replayController.stop()
        }
    }
}
