//
//  PublicRouteMapView.swift
//  MaTool
//
//  Created by 松下和也 on 2025/05/03.
//

import SwiftUI
import ComposableArchitecture

struct PublicRouteMapView: View {
    @Perception.Bindable var store: StoreOf<PublicRouteFeature>
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
                .ignoresSafeArea(edges: .bottom)
                menuLayer
            }
            .safeAreaInset(edge: .bottom) {
                if isLiquidGlassDisabled {
                    toolbarLayerBeforeLiquidGlass
                } else if #available(iOS 26.0, *) {
                    toolbarLayerAfterLiquidGlass
                }
            }
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
    var menuLayer: some View {
        VStack(spacing: 16) {
            if !store.routes.isEmpty {
                RoutePeriodMenu(
                    selected: store.selected,
                    routes: store.routes,
                    onSelected: { store.send(.selected($0)) }
                )
            }
            if let toast = store.toast {
                MapToastView(toast: toast) {
                    store.send(.toastDismissed)
                }
            }
            Spacer()
        }
        .padding(.top, 16)
    }
}

private struct RoutePeriodMenu: View {
    let selected: RouteEntry?
    let routes: [RouteEntry]
    let onSelected: (RouteEntry) -> Void

    @Environment(\.isLiquidGlassDisabled) private var isLiquidGlassDisabled

    var body: some View {
        if #available(iOS 26.0, *), !isLiquidGlassDisabled {
            menu
                .buttonStyle(.glass)
        } else {
            menu
                .background(.ultraThinMaterial, in: .rect(cornerRadius: 8))
        }
    }

    private var menu: some View {
        Menu {
            ForEach(routes) { entry in
                Button(entry.text) {
                    onSelected(entry)
                }
            }
        } label: {
            HStack(spacing: 12) {
                Text(selected?.text ?? "期間")
                    .font(.title3)
                    .lineLimit(1)
                Spacer()
                Image(systemName: "chevron.down")
                    .foregroundStyle(.secondary)
            }
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .contentShape(.rect)
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
                        if #available(iOS 17.0, *) {
                            return "point.bottomleft.forward.to.arrow.triangle.scurvepath.fill"
                        } else {
                            return "play.circle"
                        }
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
