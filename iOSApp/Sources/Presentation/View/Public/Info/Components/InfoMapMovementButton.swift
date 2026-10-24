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
        .modifier(InfoMapMovementButtonControlSize())
        .accessibilityLabel(isMapMovementLocked ? "地図の移動を有効" : "地図の移動を停止")
    }
}

private struct InfoMapMovementButtonShape: ViewModifier {
    func body(content: Content) -> some View {
        content.buttonBorderShape(.circle)
    }
}

private struct InfoMapMovementButtonControlSize: ViewModifier {
    func body(content: Content) -> some View {
        content.controlSize(.extraLarge)
    }
}

private struct InfoMapMovementButtonStyle: ViewModifier {
    let isMapMovementLocked: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if isMapMovementLocked {
            content.buttonStyle(.bordered)
        } else {
            content.buttonStyle(.borderedProminent)
        }
    }
}
