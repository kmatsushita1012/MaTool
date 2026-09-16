import Shared
import SwiftUI

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
