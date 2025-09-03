//
//  PublicRouteMapStoreView.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/05/03.
//

import SwiftUI
import ComposableArchitecture

struct PublicRouteMapStoreView: View {
    @Bindable var store: StoreOf<PublicRoute>
    @StateObject var replayController: ReplayController
    
    init(store: StoreOf<PublicRoute>) {
        self.store = store
        _replayController = StateObject(
            wrappedValue: ReplayController(
                name: store.name,
                stepDistance: 10,
                interval: 0.1,
                onEnd: { store.send(.replayEnded) }
            )
        )
    }
    
    var floatAnnotation: FloatAnnotation? {
        if store.replay.isRunning {
            return replayController.annotation
        } else  {
            return store.floatAnnotation
        }
    }
    
    
    var body: some View {
        ZStack{
            PublicRouteMap(
                points: store.pinPoints,
                polylines: store.points?.pair,
                float: floatAnnotation,
                region: $store.mapRegion,
                pointTapped: { store.send(.pointTapped($0))},
                locationTapped: { store.send(.locationTapped) }
            )
            .equatable()
            .ignoresSafeArea(edges: .bottom)
            VStack{
                Spacer()
                HStack(spacing: 16){
                    if store.replay.isRunning {
                        slider()
                    }else{
                        Spacer()
                    }
                    buttons()
                }
                .padding()
            }
            VStack{
                menu()
                    .padding()
                Spacer()
            }
            .tapOutside(isShown: $store.isMenuExpanded)
        }
        .alert($store.scope(state: \.alert, action: \.alert))
        .sheet(item: $store.detail) { detail in
            switch detail{
            case .point(let item):
                PointView(item: item)
                    .presentationDetents([.fraction(0.3), .medium, .large])
            case .location(let item):
                LocationView(item: item)
                    .presentationDetents([.fraction(0.3), .medium, .large])
            }
        }
        .onAppear{ updateReplay() }
        .onChange(of: store.route) { updateReplay() }
        .onChange(of: store.replay) { updateReplay() }
    }
    
    @ViewBuilder
    func menu()-> some View {
        VStack(spacing: 8)  {
            if let selected = store.selectedItem {
                ToggleSelectedItem(title: selected.text(format:"m/d T"), isExpanded: $store.isMenuExpanded)
                    .padding(8)
                    .background(.white)
                    .cornerRadius(8)
                    .shadow(radius: 3)
            }
            if store.isMenuExpanded,
               let others = store.others{
                ForEach(others) { route in
                    ToggleOptionItem(
                        title: route.text(format:"m/d T"),
                        onTap: { store.send(.itemSelected(route)) }
                    )
                    .padding(8)
                    .background(Color(UIColor.systemGray5))
                    .cornerRadius(8)
                    .shadow(radius: 3)
                }
            }
        }
    }
    
    @ViewBuilder
    func buttons() -> some View {
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
                icon: store.replay.isRunning
                ? "stop.circle"
                : "point.bottomleft.forward.to.arrow.triangle.scurvepath.fill"
            ){
                store.send(.replayTapped)
            }
            .disabled(!store.isReplayEnable)
        }
        .padding(8)
        .fixedSize()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white)
                .shadow(radius: 8)
        )
    }
    
    @ViewBuilder
    func slider() -> some View {
        Slider(
            value: Binding(
                get: { replayController.seekValue },
                set: { store.send(.didSeek($0)) }
            )
        )
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 32)
                .fill(Color.white.opacity(0.8))
        )
    }
    
    func updateReplay() {
        switch store.replay {
        case .initial:
            replayController.prepare(coordinates: store.points?.map{ $0.coordinate })
        case .start:
            replayController.start()
        case let .seek(progress):
            replayController.seek(to: progress)
        case .stop:
            replayController.stop()
        }
    }
}

