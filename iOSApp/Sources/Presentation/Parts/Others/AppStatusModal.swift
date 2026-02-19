//
//  AppStatusModal.swift
//  MaTool
//
//  Created by 松下和也 on 2025/07/10.
//

import SwiftUI

struct AppStatusModal: View {
    let result: StatusCheckResult
    
    init(_ result: StatusCheckResult){
        self.result = result
    }
    
    @Environment(\.dismiss) var dismiss
    @Environment(\.openURL) var openURL

    var body: some View {
        VStack(spacing: 24) {
            switch result {
            case .maintenance(let message, let until):
                Text("メンテナンス中")
                    .font(.largeTitle)
                    .bold()
                Text(message)
                    .font(.body)
                    .padding()
                Text("\(until.text(year: false)) まで")
                    .font(.body)
                    .padding()
            case .updateRequired(let storeURL):
                Text("アップデートが必要です")
                    .font(.largeTitle)
                    .bold()
                
                Button("App Storeへ") {
                    openURL(storeURL)
                }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.horizontal)
            }

            Button("閉じる") {
                dismiss()
            }
            .buttonStyle(SecondaryButtonStyle())
            .padding(.horizontal)
        }
        .padding()
    }
}
