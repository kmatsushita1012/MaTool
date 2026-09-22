import iOSShared
//
//  DistrictAreaEditContentView.swift
//  MaTool
//

import SwiftUI

@available(iOS 17.0, *)
public struct DistrictAreaEditContentView<MapContent: View>: View {
    private let map: () -> MapContent
    let onUndo: () -> Void

    public init(
        @ViewBuilder map: @escaping () -> MapContent,
        onUndo: @escaping () -> Void
    ) {
        self.map = map
        self.onUndo = onUndo
    }

    public var body: some View {
        ZStack {
            map()
                .edgesIgnoringSafeArea(.all)
            VStack {
                HStack {
                    Spacer()
                    Button(action: onUndo) {
                        Image(systemName: "arrow.uturn.backward")
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
