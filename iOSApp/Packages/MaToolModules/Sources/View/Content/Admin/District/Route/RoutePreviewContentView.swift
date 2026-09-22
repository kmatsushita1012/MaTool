import iOSShared
//
//  RoutePreviewContentView.swift
//  MaTool
//

import SwiftUI
import Shared

public struct RoutePreviewContentView: View {
    let item: ExportedItem
    @Binding var isZooming: Bool

    public init(item: ExportedItem, isZooming: Binding<Bool>) {
        self.item = item
        self._isZooming = isZooming
    }

    public var body: some View {
        ZoomableImage(image: item.image, isZooming: $isZooming)
            .ignoresSafeArea(isZooming ? .all : [])
    }
}
