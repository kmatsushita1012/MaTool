//
//  PublicRouteMapScreen.swift
//  MaTool
//  Created by 松下和也 on 2025/05/03.
//

import SwiftUI
import ComposableArchitecture

struct PublicRouteMapScreen: View {
    @Perception.Bindable var store: StoreOf<PublicRouteFeature>
    @StateObject private var replayController: ReplayController

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
        } else if let float = store.float {
            FloatCurrentAnnotation(float)
        } else {
            nil
        }
    }

    var body: some View {
        WithPerceptionTracking {
            @Binding(store.$mapRegion) var mapRegion
            PublicRouteMapContentView(
                map: {
                    MapView(
                        style: .public,
                        points: store.points,
                        floatAnnotation: floatAnnotation,
                        region: $mapRegion,
                        pointTapped: { store.send(.pointTapped($0)) },
                        floatTapped: { store.send(.locationTapped($0)) }
                    )
                    .equatable()
                },
                controls: {
                    MapRouteBottomControlsContent(
                        isReplaying: store.replay.isRunning,
                        isReplayEnabled: store.isReplayEnable,
                        seekValue: replayController.seekValue,
                        onUserFocus: { store.send(.userFocusTapped) },
                        onFloatFocus: { store.send(.floatFocusTapped) },
                        onReplay: { store.send(.replayTapped) },
                        onSeek: { store.send(.didSeek($0)) }
                    )
                }
            )
            .alert($store.scope(state: \.alert, action: \.alert))
            .sheet(item: $store.detail) { detail in
                switch detail {
                case .point(let item):
                    PointView(item)
                        .presentationDetents([.fraction(0.3), .medium, .large])
                case .location(let item):
                    LocationView(item)
                        .presentationDetents([.fraction(0.3), .medium, .large])
                }
            }
            .onAppear {
                updateReplay()
            }
            .onChange(of: store.selected) { _ in
                updateReplay()
            }
            .onChange(of: store.replay) { _ in
                updateReplay()
            }
        }
    }

    private func updateReplay() {
        switch store.replay {
        case .initial:
            replayController.prepare(coordinates: store.points.map(\.coordinate))
        case .start:
            replayController.start()
        case let .seek(progress):
            replayController.seek(to: progress)
        case .stop:
            replayController.stop()
        }
    }
}
