//
//  CardItem.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/06/03.
//

import SwiftUI

struct CardItem<Content: View>: View {
    let content: () -> Content

    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    var body: some View {
        VStack {
            content()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .layoutPriority(1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
