//
//  UpdateModal.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/07/10.
//

import SwiftUI
import Dependencies

struct UpdateModalView: View {
    @Dependency(\.updateManager) var updateManager
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack(spacing: 24) {
            Text("アップデートがあります")
                .font(.title2)
                .bold()
            
            Text("新しいバージョンをご利用いただけます。")
                .multilineTextAlignment(.center)
            
            Button("App Storeでアップデート") {
                updateManager.openAppStore()
            }
            .buttonStyle(.borderedProminent)
            Button("今回はスキップ") {
                updateManager.skipVersion()
                dismiss()
            }
            Button("閉じる") {
                dismiss()
            }
        }
        .padding()
    }
}

