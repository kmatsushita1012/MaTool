import iOSShared
import SwiftUI

@available(iOS 17.0, *)
public struct RouteEditBottomToolbarContentView: View {
    let isInfo: Bool
    let canUndo: Bool
    let canRedo: Bool
    let operation: RouteEditOperation
    let isLoading: Bool
    let isPartialEnabled: Bool
    @Binding var isDialogPresented: Bool
    let onCopy: () -> Void
    let onUndo: () -> Void
    let onRedo: () -> Void
    let onWhole: () -> Void
    let onPartial: () -> Void

    public init(
        isInfo: Bool,
        canUndo: Bool,
        canRedo: Bool,
        operation: RouteEditOperation,
        isLoading: Bool,
        isPartialEnabled: Bool,
        isDialogPresented: Binding<Bool>,
        onCopy: @escaping () -> Void,
        onUndo: @escaping () -> Void,
        onRedo: @escaping () -> Void,
        onWhole: @escaping () -> Void,
        onPartial: @escaping () -> Void
    ) {
        self.isInfo = isInfo
        self.canUndo = canUndo
        self.canRedo = canRedo
        self.operation = operation
        self.isLoading = isLoading
        self.isPartialEnabled = isPartialEnabled
        self._isDialogPresented = isDialogPresented
        self.onCopy = onCopy
        self.onUndo = onUndo
        self.onRedo = onRedo
        self.onWhole = onWhole
        self.onPartial = onPartial
    }

    public var body: some View {
        HStack {
            if isInfo {
                Button("コピー", action: onCopy)
            } else {
                Button(systemImage: "arrow.uturn.backward", action: onUndo)
                    .disabled(!canUndo)
                Button(systemImage: "arrow.uturn.forward", action: onRedo)
                    .disabled(!canRedo)
                Spacer()
                RouteLongPressModeContentView(operation: operation)
            }
            Spacer()
            RouteEditSubmitButton(
                isLoading: isLoading,
                isPartialEnabled: isPartialEnabled,
                isDialogPresented: $isDialogPresented,
                onWhole: onWhole,
                onPartial: onPartial
            )
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal)
        .padding(.vertical, 4)
    }
}
