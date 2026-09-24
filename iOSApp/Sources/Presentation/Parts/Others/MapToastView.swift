//
//  MapToastView.swift
//  MaTool
//
//  Created by Codex on 2026/09/24.
//

import SwiftUI

struct MapToast: Equatable, Sendable {
    let title: String
    let message: String

    static func error(_ message: String, title: String = "エラー") -> Self {
        Self(title: title, message: message)
    }

    static func error(_ error: AppError, title: String = "エラー") -> Self {
        Self.error(error.message, title: title)
    }

    static func notice(_ message: String, title: String = "お知らせ") -> Self {
        Self(title: title, message: message)
    }
}

struct MapToastView: View {
    let toast: MapToast
    let onDismiss: () -> Void

    @Environment(\.isLiquidGlassDisabled) private var isLiquidGlassDisabled

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                Text(toast.title)
                    .font(.headline.weight(.bold))
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text(toast.message)
                    .font(.body)
                    .fixedSize(horizontal: false, vertical: true)
            }

            dismissButton
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .mapToastSurface(isLiquidGlassDisabled: isLiquidGlassDisabled)
        .padding(.horizontal, 16)
    }

    @ViewBuilder
    private var dismissButton: some View {
        if #available(iOS 17.0, *) {
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.body.weight(.semibold))
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .buttonBorderShape(.circle)
            .accessibilityLabel("閉じる")
        } else {
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.body.weight(.semibold))
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .clipShape(Circle())
            .accessibilityLabel("閉じる")
        }
    }
}

private struct MapToastSurface: ViewModifier {
    let isLiquidGlassDisabled: Bool

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *), !isLiquidGlassDisabled {
            content
                .glassEffect(.regular, in: .rect(cornerRadius: 16))
        } else {
            content
                .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
        }
    }
}

private extension View {
    func mapToastSurface(isLiquidGlassDisabled: Bool) -> some View {
        modifier(MapToastSurface(isLiquidGlassDisabled: isLiquidGlassDisabled))
    }
}
