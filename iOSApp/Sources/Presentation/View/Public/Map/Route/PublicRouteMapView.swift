//
//  PublicRouteMapView.swift
//  MaTool
//
//  Created by 松下和也 on 2025/05/03.
//

import SwiftUI
import ComposableArchitecture

struct PublicRouteMapView: View {
    @SwiftUI.Bindable var store: StoreOf<PublicRouteFeature>
    @StateObject var replayController: ReplayController
    @Namespace private var namespace
    
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
    
    @Environment(\.isLiquidGlassDisabled) var isLiquidGlassDisabled
    
    var body: some View {
        WithPerceptionTracking{
            @Binding(store.$mapRegion) var mapRegion
            ZStack{
                MapView(
                    style: .public,
                    points: store.points,
                    floatAnnotation: floatAnnotation,
                    region: $mapRegion,
                    pointTapped: { store.send(.pointTapped($0))},
                    floatTapped: { store.send(.locationTapped($0)) }
                )
                .equatable()
                .ignoresSafeArea(.all)
            }
            .safeAreaInset(edge: .bottom) {
                Group {
                    if isLiquidGlassDisabled {
                        toolbarLayerBeforeLiquidGlass
                    } else if #available(iOS 26.0, *) {
                        toolbarLayerAfterLiquidGlass
                    }
                }
                .padding()
            }
            .sheet(item: $store.detail) { detail in
                switch detail{
                case .point(let item):
                    PointView(item)
                        .presentationDetents([.fraction(0.3), .medium, .large])
                }
            }
            .onAppear {
                store.send(.onAppear)
                updateReplay()
            }
            .onChange(of: store.selected) { _ in updateReplay() }
            .onChange(of: store.replay) { _ in updateReplay() }
        }
    }
    
}
    
extension PublicRouteMapView {
    
    @ViewBuilder
    var toolbarLayerBeforeLiquidGlass: some View {
        VStack{
            Spacer()
            HStack(spacing: 16){
                if store.replay.isRunning {
                    slider
                }else{
                    Spacer()
                }
                buttons
            }
            .padding()
        }
    }
    
    @ViewBuilder
    var buttons: some View {
        HStack {
            FloatingIconButton(icon: "location.fill"){
                store.send(.userFocusTapped)
            }
            Divider()
            FloatingIconButton(icon: "mappin.and.ellipse"){
                store.send(.floatFocusTapped)
            }
            Divider()
            FloatingIconButton(
                icon: {
                    if store.replay.isRunning {
                        return "stop.circle"
                    } else {
                        return "point.bottomleft.forward.to.arrow.triangle.scurvepath.fill"
                    }
                }()
            ){
                store.send(.replayTapped)
            }
            .disabled(!store.isReplayEnable)
        }
        .padding(8)
        .fixedSize()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(uiColor: .systemBackground))
                .shadow(radius: 8)
        )
    }
    
    @ViewBuilder
    var slider: some View {
        Slider(
            value: Binding(
                get: { replayController.seekValue },
                set: { store.send(.didSeek($0)) }
            )
        )
        .padding(.horizontal, 16)
        .ifLiquidGlass(before: {
            $0.background(
                RoundedRectangle(cornerRadius: 32)
                    .fill(Color(uiColor: .systemBackground).opacity(0.8))
            )
        })
    }
}

extension PublicRouteMapView {
    @available(iOS 26.0, *)
    @ViewBuilder
    var toolbarLayerAfterLiquidGlass: some View {
        
        HStack(spacing: 8) {
            Group {
                if store.replay.isRunning {
                    slider
                        .glassEffect(in: .capsule)
                } else {
                    Color.clear
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity)
            
            GlassEffectContainer(spacing:8) {
                HStack(spacing: 8) {
                    
                    FloatingIconButton(icon: "location.fill") {
                        store.send(.userFocusTapped)
                    }
                    .glassEffectUnion(id: "bottombar", namespace: namespace)
                    
                    FloatingIconButton(icon: "mappin.and.ellipse") {
                        store.send(.floatFocusTapped)
                    }
                    .glassEffectUnion(id: "bottombar", namespace: namespace)
                    
                    FloatingIconButton(
                        icon: store.replay.isRunning
                            ? "stop.circle"
                            : "point.bottomleft.forward.to.arrow.triangle.scurvepath.fill"
                    ) {
                        store.send(.replayTapped)
                    }
                    .glassEffectUnion(id: "bottombar", namespace: namespace)
                    .disabled(!store.isReplayEnable)
                }
            }
        }
        .padding(.horizontal)
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
