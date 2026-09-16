//
//  RoutePreviewContentView.swift
//  MaTool
//

import SwiftUI
import Shared

struct RoutePreviewContentView: View {
    let item: ExportedItem
    @Binding var isZooming: Bool

    var body: some View {
        ZoomableImage(image: item.image, isZooming: $isZooming)
            .ignoresSafeArea(isZooming ? .all : [])
    }
}
