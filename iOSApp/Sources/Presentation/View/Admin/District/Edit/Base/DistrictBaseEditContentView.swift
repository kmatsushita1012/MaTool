//
//  DistrictBaseEditContentView.swift
//  MaTool
//

import SwiftUI

@available(iOS 17.0, *)
struct DistrictBaseEditContentView<MapContent: View>: View {
    private let map: () -> MapContent
    let onClear: () -> Void

    init(
        @ViewBuilder map: @escaping () -> MapContent,
        onClear: @escaping () -> Void
    ) {
        self.map = map
        self.onClear = onClear
    }

    var body: some View {
        ZStack {
            map()
                .edgesIgnoringSafeArea(.all)
            VStack {
                HStack {
                    Spacer()
                    Button(action: onClear) {
                        Image(systemName: "eraser")
                            .font(.title2)
                            .padding(12)
                            .background(Color(.systemBackground).opacity(0.8))
                            .clipShape(Circle())
                    }
                    .padding()
                }
                Spacer()
            }
        }
    }
}
