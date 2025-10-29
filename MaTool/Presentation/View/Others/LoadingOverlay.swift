//
//  ProgressScreen.swift
//  MaTool
//
//  Created by 松下和也 on 2025/05/16.
//

import SwiftUI

extension View {
    func loadingOverlay(_ isLoading: Bool) -> some View {
        ZStack {
            self
            if isLoading {
                Color.black.opacity(0.2)
                    .ignoresSafeArea()
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(2)
            }
        }
    }
}

extension View {
    func loadingOverlay(
        _ isLoading: Bool,
        message: String = "キャンセル",
        onCancel: @escaping () -> Void
    ) -> some View {
        ZStack {
            self
            if isLoading {
                Color.black.opacity(0.2)
                    .ignoresSafeArea()

                VStack(spacing: 16) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(2)

                    Button(action: onCancel) {
                        Text(message)
                            .foregroundColor(.white)
                            .underline()
                            .font(.body)
                            .padding(8)
                    }
                    .background(Color.black.opacity(0.5))
                    .cornerRadius(16)
                }
            }
        }
        .animation(.easeInOut, value: isLoading)
    }
}
