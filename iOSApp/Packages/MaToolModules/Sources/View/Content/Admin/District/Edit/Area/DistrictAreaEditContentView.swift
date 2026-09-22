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
    let onCancel: () -> Void
    let onDone: () -> Void

    public init(
        @ViewBuilder map: @escaping () -> MapContent,
        onUndo: @escaping () -> Void,
        onCancel: @escaping () -> Void,
        onDone: @escaping () -> Void
    ) {
        self.map = map
        self.onUndo = onUndo
        self.onCancel = onCancel
        self.onDone = onDone
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
        .navigationTitle("町域")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarCancelButton(action: onCancel)
            ToolbarDoneButton(action: onDone)
        }
        .toolbarBackground(.visible, for: .navigationBar)
    }
}
