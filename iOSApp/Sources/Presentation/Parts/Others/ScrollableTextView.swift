//
//  ScrollableTextView.swift
//  MaTool
//
//  Created by 松下和也 on 2025/08/09.
//

import SwiftUI

struct ScrollableTextView: View {
    let text: String
    let maxHeight: CGFloat

    init(_ text: String, maxHeight: CGFloat = 200) {
        self.text = text
        self.maxHeight = maxHeight
    }

    var body: some View {
        ScrollView {
            Text(text)
                .frame(maxWidth: .infinity, alignment: .leading)
                .multilineTextAlignment(.leading)
        }
        .frame(maxHeight: maxHeight)
    }
}
