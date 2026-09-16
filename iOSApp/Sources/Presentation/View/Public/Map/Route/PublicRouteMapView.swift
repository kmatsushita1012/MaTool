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
    var menuLayer: some View {
        VStack{
            menu
                .padding()
            Spacer()
        }
        .tapOutside(isShown: $store.isMenuExpanded)
    }
    
    @ViewBuilder
    var menu: some View {
        VStack(spacing: 8)  {
            if let selected = store.selected {
                ToggleSelectedItem(title: selected.text, isExpanded: $store.isMenuExpanded) // FIXME
                    .padding(8)
                    .background(Color(uiColor: .systemBackground))
                    .cornerRadius(8)
                    .shadow(radius: 3)
            }
            if store.isMenuExpanded  {
                ForEach(store.others) { entry in
                    WithPerceptionTracking{
                        ToggleOptionItem(
                            title: entry.text,
                            onTap: { store.send(.selected(entry)) }
                        )
                        .padding(8)
                        .background(Color(UIColor.systemGray5))
                        .cornerRadius(8)
                        .shadow(radius: 3)
                    }
                }
            }
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
                    
                    button(systemImage: "location.fill") {
                        store.send(.userFocusTapped)
                    }
                    
                    button(systemImage: "mappin.and.ellipse") {
                        store.send(.floatFocusTapped)
                    }
                    
                    button(
                        systemImage: {
                            if store.replay.isRunning {
                                return "stop.circle"
                            } else {
                                return "point.bottomleft.forward.to.arrow.triangle.scurvepath.fill"
//                                return "stop.circle"
                            }
                        }()
                    ) {
                        store.send(.replayTapped)
                    }
                    .disabled(!store.isReplayEnable)
                }
            }
        }
        .padding(.horizontal)
    }
    
    @available(iOS 26.0, *)
    @ViewBuilder
    private func button(systemImage: String, action: @escaping @MainActor () -> Void) -> some View{
        Button {
            action()
        } label: {
            Image(systemName: systemImage)
                .font(.title2)
                .contentShape(.rect)
        }
        .buttonStyle(.glass)
        .glassEffectUnion(id: "bottombar", namespace: namespace)
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
