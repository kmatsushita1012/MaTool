import ComposableArchitecture
import Shared
import SwiftUI

struct MapLocationsBottomControlsView: View {
    let store: StoreOf<PublicLocationsFeature>

    var body: some View {
        WithPerceptionTracking {
            MapLocationsBottomControlsContent(
                floats: store.floats,
                onUserFocus: { store.send(.userFocusTapped) },
                onFloatFocus: { store.send(.floatFocusSelected($0)) },
                onReload: { store.send(.reloadTapped) }
            )
        }
    }
}

struct MapLocationsBottomControlsContent: View {
    let floats: [FloatEntry]
    let onUserFocus: () -> Void
    let onFloatFocus: (FloatEntry) -> Void
    let onReload: () -> Void

    var body: some View {
        MapGlassControlsContainer(variant: .toolbar) { namespace in
            MapGlassButton(
                systemImage: "location.fill",
                accessibilityLabel: "現在地",
                action: onUserFocus,
                namespace: namespace
            )

            MapGlassMenu(
                floats: floats,
                onSelected: onFloatFocus,
                namespace: namespace
            )

            MapGlassButton(
                systemImage: "arrow.clockwise",
                accessibilityLabel: "更新",
                action: onReload,
                namespace: namespace
            )
        }
    }
}

struct MapRouteBottomControlsView: View {
    let store: StoreOf<PublicRouteFeature>
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

    var body: some View {
        WithPerceptionTracking {
            MapRouteBottomControlsContent(
                isReplaying: store.replay.isRunning,
                isReplayEnabled: store.isReplayEnable,
                seekValue: replayController.seekValue,
                onUserFocus: { store.send(.userFocusTapped) },
                onFloatFocus: { store.send(.floatFocusTapped) },
                onReplay: { store.send(.replayTapped) },
                onSeek: { store.send(.didSeek($0)) }
            )
            .onAppear { updateReplay() }
            .onChange(of: store.replay) { _ in updateReplay() }
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

struct MapRouteBottomControlsContent: View {
    let isReplaying: Bool
    let isReplayEnabled: Bool
    let seekValue: Double
    let onUserFocus: () -> Void
    let onFloatFocus: () -> Void
    let onReplay: () -> Void
    let onSeek: (Double) -> Void

    var body: some View {
        MapGlassControlRow(
            isReplaying: isReplaying,
            spacing: MapGlassControlVariant.toolbar.sliderSpacing,
            slider: {
                Slider(value: Binding(get: { seekValue }, set: onSeek))
                    .mapSliderGlass(variant: .toolbar)
                    .accessibilityLabel("ルートの進行")
            },
            controls: {
                MapGlassControlsContainer(variant: .toolbar) { namespace in
                    MapGlassButton(
                        systemImage: "location.fill",
                        accessibilityLabel: "現在地",
                        action: onUserFocus,
                        namespace: namespace
                    )

                    MapGlassButton(
                        systemImage: "mappin.and.ellipse",
                        accessibilityLabel: "現在地を表示",
                        action: onFloatFocus,
                        namespace: namespace
                    )

                    MapGlassButton(
                        systemImage: isReplaying
                            ? "stop.circle"
                            : "point.bottomleft.forward.to.arrow.triangle.scurvepath.fill",
                        accessibilityLabel: isReplaying ? "再生を停止" : "ルートを再生",
                        action: onReplay,
                        namespace: namespace
                    )
                    .disabled(!isReplayEnabled)
                }
            }
        )
    }
}

private struct MapGlassControlsContainer<Content: View>: View {
    let content: (Namespace.ID) -> Content
    let variant: MapGlassControlVariant
    @Namespace private var glassNamespace

    init(
        variant: MapGlassControlVariant,
        @ViewBuilder content: @escaping (Namespace.ID) -> Content
    ) {
        self.variant = variant
        self.content = content
    }

    var body: some View {
        if #available(iOS 26.0, *) {
            GlassEffectContainer(spacing: variant.spacing) {
                HStack(spacing: variant.spacing) {
                    content(glassNamespace)
                }
            }
        } else {
            HStack(spacing: 0) {
                content(glassNamespace)
            }
            .buttonStyle(.plain)
            .padding(variant.contentPadding)
            .background(.ultraThinMaterial, in: Capsule())
        }
    }
}

private struct MapGlassControlRow<SliderContent: View, ControlsContent: View>: View {
    let isReplaying: Bool
    let spacing: CGFloat
    let sliderContent: SliderContent
    let controlsContent: ControlsContent

    init(
        isReplaying: Bool,
        spacing: CGFloat,
        @ViewBuilder slider: () -> SliderContent,
        @ViewBuilder controls: () -> ControlsContent
    ) {
        self.isReplaying = isReplaying
        self.spacing = spacing
        self.sliderContent = slider()
        self.controlsContent = controls()
    }

    var body: some View {
        HStack(alignment: .center, spacing: spacing) {
            if isReplaying {
                sliderContent
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Spacer(minLength: 0)
            }
            controlsContent
        }
        .frame(maxWidth: .infinity)
    }
}

enum MapGlassControlVariant {
    case toolbar

    var spacing: CGFloat {
        0
    }

    var sliderSpacing: CGFloat {
        16
    }

    var edgeSpacing: CGFloat {
        16
    }

    var contentPadding: CGFloat {
        8
    }

    var controlSize: ControlSize {
        .mini
    }

    @available(iOS 26.0, *)
    var glass: Glass {
        .regular.interactive()
    }
}

private struct MapGlassButton: View {
    let systemImage: String
    let accessibilityLabel: String
    let action: () -> Void
    let namespace: Namespace.ID

    @ViewBuilder
    var body: some View {
        if #available(iOS 26.0, *) {
            Button(action: action) {
                Label("", systemImage: systemImage)
                    .labelStyle(.iconOnly)
                    .font(.title2)
                    .padding(.vertical, 4)
            }
                .buttonStyle(.glass)
                .accessibilityLabel(accessibilityLabel)
                .glassEffectUnion(
                    id: "toolbar",
                    namespace: namespace
                )
        } else {
            Button(action: action) {
                Label("", systemImage: systemImage)
                    .labelStyle(.iconOnly)
                    .font(.title2)
                    .padding(.vertical, 4)
            }
                .buttonStyle(.plain)
                .accessibilityLabel(accessibilityLabel)
        }
    }
}

private struct MapGlassMenu: View {
    let floats: [FloatEntry]
    let onSelected: (FloatEntry) -> Void
    let namespace: Namespace.ID

    @ViewBuilder
    var body: some View {
        if #available(iOS 26.0, *) {
            menu
                .buttonStyle(.glass)
                .glassEffectUnion(id: "toolbar", namespace: namespace)
        } else {
            menu.buttonStyle(.plain)
        }
    }

    private var menu: some View {
        Menu {
            ForEach(floats, id: \.self) { entry in
                Button(entry.district.name) {
                    onSelected(entry)
                }
            }
        } label: {
            Label("", systemImage: "mappin.and.ellipse")
                .labelStyle(.iconOnly)
                .font(.title2)
                .padding(8)
        }
        .accessibilityLabel("現在地を選択")
    }
}

private extension View {
    @ViewBuilder
    func mapSliderGlass(variant: MapGlassControlVariant) -> some View {
        let slider = controlSize(variant.controlSize)
            .frame(maxWidth: .infinity)
            .padding(variant.contentPadding)

        if #available(iOS 26.0, *) {
            slider.glassEffect(variant.glass, in: .capsule)
        } else {
            slider.background(.ultraThinMaterial, in: Capsule())
        }
    }
}
