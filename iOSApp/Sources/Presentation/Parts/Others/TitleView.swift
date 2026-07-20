//
//  TitleView.swift
//  MaTool
//
//  Created by 松下和也 on 2025/06/14.
//

import SwiftUI

struct TitleView: View {
    let text: String
    let image: String
    var isDismissEnabled: Bool = true
    var font: Font = .largeTitle
    let onDismiss: () -> Void
    

    // UIImageから縦横比を計算（UIImageが取れなければデフォルト比率）
    private var aspectRatio: CGFloat {
        if let uiImage = UIImage(named: image) {
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
                Image(image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: width, height: height)
                    .clipped()
                VStack {
                    Spacer()
                    ZStack {
                        Text(text)
                            .font(font)
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
