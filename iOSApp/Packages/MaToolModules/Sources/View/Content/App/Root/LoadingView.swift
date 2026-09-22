import iOSShared
//
//  LoadingView.swift
//  MaTool
//
//  Created by 松下和也 on 2026/02/25.
//

import SwiftUI

public struct LoadingView: View {
    public init() {}

    public var body: some View {
        ZStack {
            Image("OnboardingBackground")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
                .allowsHitTesting(false)
                .accessibilityHidden(true)

            VStack(spacing: 16) {
                Spacer()
                Image("LaunchImage")
                HStack {
                    Text("読み込み中")
                        .font(.title)
                        .foregroundStyle(.secondary)
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.secondary)
                }
                Spacer()
            }
            .padding()
        }
    }
}
