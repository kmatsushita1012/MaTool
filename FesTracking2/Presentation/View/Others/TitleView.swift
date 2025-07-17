//
//  Untitled.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/06/14.
//

import SwiftUI

struct TitleView: View {
    let imageName: String
    let titleText: String
    var isDismissEnabled: Bool = true
    let onDismiss: () -> Void

    // UIImageから縦横比を計算（UIImageが取れなければデフォルト比率）
    private var aspectRatio: CGFloat {
        if let uiImage = UIImage(named: imageName) {
            return uiImage.size.height / uiImage.size.width
        } else {
            return 297.0 / 397.0  // デフォルト比率
        }
    }

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = width * aspectRatio

            ZStack(alignment: .topLeading) {
                Image(imageName)
                    .resizable()
                    .scaledToFill()
                    .frame(width: width, height: height)
                    .clipped()
                VStack {
                    Spacer()
                    ZStack {
                        Text(titleText)
                            .font(.largeTitle)
                            .bold()
                        HStack {
                            DismissButton(isEnabled: isDismissEnabled) {
                                onDismiss()
                            }
                            .padding()
                            Spacer()
                        }
                    }
                    Spacer()
                }
            }
            .frame(width: width, height: height)
        }
        .frame(height: UIScreen.main.bounds.width * aspectRatio)
    }
}
