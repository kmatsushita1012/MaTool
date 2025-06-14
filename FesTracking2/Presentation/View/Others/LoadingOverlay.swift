//
//  ProgressScreen.swift
//  FesTracking2
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
                    .scaleEffect(1.5)
            }
        }
    }
}
