//
//  ZoomableImage.swift
//  MaTool
//
//  Created by 松下和也 on 2025/08/03.
//

import SwiftUI
import UIKit

struct ZoomableImage: UIViewRepresentable {
    let image: UIImage
    @Binding var isZooming: Bool   // ← 追加

    func makeCoordinator() -> Coordinator {
        Coordinator(isZooming: $isZooming)
    }

    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.delegate = context.coordinator
        scrollView.minimumZoomScale = 1.0
        scrollView.maximumZoomScale = 5.0
        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.bouncesZoom = true
        scrollView.bounces = true
        scrollView.backgroundColor = .clear
        scrollView.contentInsetAdjustmentBehavior = .never

        let imageView = UIImageView(image: image)
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.clipsToBounds = true

        scrollView.addSubview(imageView)
        context.coordinator.imageView = imageView
        context.coordinator.scrollView = scrollView

        NSLayoutConstraint.activate([
            imageView.centerXAnchor.constraint(equalTo: scrollView.centerXAnchor),
            imageView.centerYAnchor.constraint(equalTo: scrollView.centerYAnchor),
            imageView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            imageView.heightAnchor.constraint(equalTo: scrollView.heightAnchor)
        ])

        return scrollView
    }

    func updateUIView(_ uiView: UIScrollView, context: Context) {}

    class Coordinator: NSObject, UIScrollViewDelegate {
        weak var imageView: UIView?
        weak var scrollView: UIScrollView?
        @Binding var isZooming: Bool

        init(isZooming: Binding<Bool>) {
            _isZooming = isZooming
        }

        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            imageView
        }

        func scrollViewDidZoom(_ scrollView: UIScrollView) {
            guard let imageView = imageView else { return }

            // SafeArea 切り替え用
            isZooming = scrollView.zoomScale > 1.01

            // 中央寄せ
            let offsetX = max((scrollView.bounds.width - scrollView.contentSize.width) * 0.5, 0)
            let offsetY = max((scrollView.bounds.height - scrollView.contentSize.height) * 0.5, 0)

            imageView.center = CGPoint(
                x: scrollView.contentSize.width * 0.5 + offsetX,
                y: scrollView.contentSize.height * 0.5 + offsetY
            )
        }
    }
}
