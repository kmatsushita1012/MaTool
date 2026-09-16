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
    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 17.0, *) {
            content.buttonBorderShape(.circle)
        } else {
            content.clipShape(Circle())
        }
    }
}

private struct InfoMapMovementButtonControlSize: ViewModifier {
    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 17.0, *) {
            content.controlSize(.extraLarge)
        } else {
            content.controlSize(.large)
        }
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
