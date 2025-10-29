//
//  Untitled.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/07/29.
//

import SwiftUI
import Kingfisher
import Perception

typealias ContentMode = SwiftUI.ContentMode

struct WebImageView: View {
    let imagePath: String
    let contentMode: ContentMode

    init(imagePath: String, contentMode: ContentMode = .fill) {
        self.imagePath = imagePath
        self.contentMode = contentMode
    }

    var body: some View {
        if let url = URL(string: imagePath) {
            KFImage(url)
                .placeholder {
                    WithPerceptionTracking{
                        ProgressView()
                    }
                }
                .cacheOriginalImage()
                .resizable()
                .aspectRatio(contentMode: contentMode)
                .clipped()
        } else {
            fallbackView
        }
    }

    private var fallbackView: some View {
        ZStack {
            Color.gray.opacity(0.2)
            Text("No Image")
                .foregroundColor(.secondary)
                .font(.caption)
        }
    }
}
