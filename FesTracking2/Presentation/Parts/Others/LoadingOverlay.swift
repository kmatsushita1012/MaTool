//
//  ProgressScreen.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/05/16.
//

import SwiftUI

struct ProgressScreen<Content: View>: View {
    let isLoading: Bool
    let content: () -> Content

    init(isLoading: Bool, @ViewBuilder content: @escaping () -> Content) {
        self.isLoading = isLoading
        self.content = content
    }

    var body: some View {
        ZStack {
            content()
            if isLoading {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.5)
            }
        }
    }
}
