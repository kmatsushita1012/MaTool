import iOSShared
//
//  PublicLocationsMapContentView.swift
//  MaTool
//

import SwiftUI

public struct PublicLocationsMapContentView<MapContent: View, ControlsContent: View>: View {
    private let map: () -> MapContent
    private let controls: () -> ControlsContent

    public init(
        @ViewBuilder map: @escaping () -> MapContent,
        @ViewBuilder controls: @escaping () -> ControlsContent
    ) {
        self.map = map
        self.controls = controls
    }

    public var body: some View {
        if #available(iOS 26.0, *) {
            map()
                .ignoresSafeArea()
                .scrollEdgeEffectStyle(.soft, for: .top)
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    controls()
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .padding(.horizontal, MapGlassControlVariant.toolbar.edgeSpacing)
                        .padding(.bottom, 8)
                }
        } else {
            map()
                .ignoresSafeArea()
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    controls()
                        .padding(.bottom, 72)
                }
        }
    }
}
