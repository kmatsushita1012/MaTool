import SwiftUI

struct InfoMapMovementButton: View {
    @Binding var isMapMovementLocked: Bool

    var body: some View {
        Button {
            isMapMovementLocked.toggle()
        } label: {
            Label("", systemImage: "arrow.up.and.down.and.arrow.left.and.right")
                .labelStyle(.iconOnly)
                .padding(8)
        }
        .modifier(InfoMapMovementButtonStyle(isMapMovementLocked: isMapMovementLocked))
        .modifier(InfoMapMovementButtonShape())
        .accessibilityLabel(isMapMovementLocked ? "地図の移動を有効" : "地図の移動を停止")
    }
}

private struct InfoMapMovementButtonShape: ViewModifier {
    func body(content: Content) -> some View {
        content.buttonBorderShape(.circle)
    }
}

private struct InfoMapMovementButtonStyle: ViewModifier {
    let isMapMovementLocked: Bool
    @Environment(\.isLiquidGlassDisabled) private var isLiquidGlassDisabled

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *), !isLiquidGlassDisabled {
            if isMapMovementLocked {
                content.buttonStyle(.glass)
            } else {
                content
                    .buttonStyle(.glass)
                    .tint(.accentColor)
            }
        } else if isMapMovementLocked {
            content.buttonStyle(.bordered)
        } else {
            content
                .buttonStyle(.borderedProminent)
                .tint(.accentColor)
        }
    }
}
