import iOSShared
//
//  WebImageView.swift
//  MaTool
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
    let onImageLoaded: ((CGSize) -> Void)?

    init(
        imagePath: String,
        contentMode: ContentMode = .fill,
        onImageLoaded: ((CGSize) -> Void)? = nil
    ) {
        self.imagePath = imagePath
        self.contentMode = contentMode
        self.onImageLoaded = onImageLoaded
    }

    var body: some View {
        if let url = URL(string: imagePath) {
            KFImage(url)
                .onSuccess { result in
                    onImageLoaded?(result.image.size)
                }
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
