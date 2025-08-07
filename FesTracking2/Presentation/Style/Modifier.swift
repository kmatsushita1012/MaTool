//
//  Modifier.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/07/27.
//

import SwiftUI

struct RelativeFrame: ViewModifier {
    var width: CGFloat? = nil
    var height: CGFloat? = nil

    func body(content: Content) -> some View {
        GeometryReader { geometry in
            let w = width.map { geometry.size.width * $0 }
            let h = height.map { geometry.size.height * $0 }

            content
                .frame(width: w, height: h)
                .position(
                    x: w.map { $0 / 2 } ?? geometry.size.width / 2,
                    y: h.map { $0 / 2 } ?? geometry.size.height / 2
                )
        }
    }
}

extension View {
    func frame(width: CGFloat? = nil, height: CGFloat? = nil, relative: Bool) -> some View {
        if relative {
            return AnyView(self.modifier(RelativeFrame(width: width, height: height)))
        } else {
            return AnyView(self.frame(
                width: width,
                height: height
            ))
        }
    }
}
