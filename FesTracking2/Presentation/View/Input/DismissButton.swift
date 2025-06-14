//
//  RouteButton.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/04/08.
//
import SwiftUI

struct DismissButton: View {
    let isEnabled: Bool
    let action: () -> Void

    init(isEnabled: Bool = true, action: @escaping () -> Void) {
        self.isEnabled = isEnabled
        self.action = action
    }
    var body: some View{
        Button(action: action) {
            Image(systemName: "arrow.left")
                .foregroundColor(.black)
                .frame(width: 48, height: 48)
                .background(
                    Circle()
                        .stroke(Color.gray, lineWidth: 1)
                )
        }
        .disabled(!isEnabled)
    }
}
