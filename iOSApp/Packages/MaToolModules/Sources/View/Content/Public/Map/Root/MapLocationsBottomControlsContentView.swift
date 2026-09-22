import iOSShared
import Shared
import SwiftUI

public struct MapLocationsBottomControlsContent: View {
    let floats: [FloatEntry]
    let onUserFocus: () -> Void
    let onFloatFocus: (FloatEntry) -> Void
    let onReload: () -> Void

    public init(
        floats: [FloatEntry],
        onUserFocus: @escaping () -> Void,
        onFloatFocus: @escaping (FloatEntry) -> Void,
        onReload: @escaping () -> Void
    ) {
        self.floats = floats
        self.onUserFocus = onUserFocus
        self.onFloatFocus = onFloatFocus
        self.onReload = onReload
    }

    public var body: some View {
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
