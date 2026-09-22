import iOSShared
import SwiftUI

public struct MapRouteBottomControlsContent: View {
    let isReplaying: Bool
    let isReplayEnabled: Bool
    let seekValue: Double
    let onUserFocus: () -> Void
    let onFloatFocus: () -> Void
    let onReplay: () -> Void
    let onSeek: (Double) -> Void

    public init(
        isReplaying: Bool,
        isReplayEnabled: Bool,
        seekValue: Double,
        onUserFocus: @escaping () -> Void,
        onFloatFocus: @escaping () -> Void,
        onReplay: @escaping () -> Void,
        onSeek: @escaping (Double) -> Void
    ) {
        self.isReplaying = isReplaying
        self.isReplayEnabled = isReplayEnabled
        self.seekValue = seekValue
        self.onUserFocus = onUserFocus
        self.onFloatFocus = onFloatFocus
        self.onReplay = onReplay
        self.onSeek = onSeek
    }

    public var body: some View {
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
