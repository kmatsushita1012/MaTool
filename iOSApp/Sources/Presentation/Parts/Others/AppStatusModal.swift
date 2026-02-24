//
//  AppStatusModal.swift
//  MaTool
//
//  Created by 松下和也 on 2025/07/10.
//

import SwiftUI

struct AppStatusModal: View {
    let result: StatusCheckResult
    let canDismiss: Bool
    
    init(_ result: StatusCheckResult, canDismiss: Bool = true){
        self.result = result
        self.canDismiss = canDismiss
    }
    
    @Environment(\.dismiss) var dismiss
    @Environment(\.openURL) var openURL

    var body: some View {
        ZStack{
            Image("OnboardingBackground")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            VStack(alignment: .center, spacing: 32) {
                switch result {
                case .maintenance(let message, let until):
                    VStack(spacing: 16) {
                        Text("メンテナンス中")
                            .font(.title)
                        Text(message)
                        Text("終了予定日:\(until.text(of: "yyyy/MM/dd"))")
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    .clipShape(
                        RoundedRectangle(cornerRadius: 16)
                    )
                case .updateRequired(let storeURL):
                    VStack(spacing: 16) {
                        Text("アップデートが必要です")
                            .font(.title)
                        Text("ご迷惑をおかけしますが、最新の機能を提供できるようになります。")
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    .clipShape(
                        RoundedRectangle(cornerRadius: 16)
                    )
                    Button("App Storeでアップデート") {
                        openURL(storeURL)
                    }
                    .buttonStyle(PrimaryButtonStyle(backgroundColor: .launch))
                }
                if canDismiss {
                    Button("閉じる") {
                        dismiss()
                    }
                    .padding(.horizontal)
                    .buttonStyle(SecondaryButtonStyle(foregroundColor: .launch, borderColor: .launch))
                }
                
            }
            .padding()
        }
    }
}
