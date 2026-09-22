import iOSShared
//
//  HazardSectionContentView.swift
//  MaTool
//

import SwiftUI
import Shared

@available(iOS 17.0, *)
public struct HazardSectionContentView<MapContent: View>: View {
    @Binding var item: HazardSection
    private let map: () -> MapContent

    public init(
        item: Binding<HazardSection>,
        @ViewBuilder map: @escaping () -> MapContent
    ) {
        self._item = item
        self.map = map
    }

    public var body: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading) {
                Text("タイトル")
                    .font(.headline)
                    .foregroundStyle(.gray)
                TextField(
                    "注釈の内容（例: 斜度 5°）",
                    text: $item.title
                )
                .padding()
                .background(.background)
                .clipShape(.capsule)
            }
            map()
                .roundedRect()
        }
        .padding()
    }
}
