//
//  ButtonStyle.swift
//  MaTool
//
//  Created by 松下和也 on 2025/05/26.
//

import SwiftUI

struct PrimaryButtonStyle: ButtonStyle {
    let backgroundColor: Color
    let foregroundColor: Color
    
    init(backgroundColor: Color = .blue, foregroundColor: Color = .white) {
        self.backgroundColor = backgroundColor
        self.foregroundColor = foregroundColor
    }
    
    init(_ color: Color = .blue) {
        self.backgroundColor = color
        self.foregroundColor = .white
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .fontWeight(.semibold)
            .frame(maxWidth: .infinity)
            .padding()
            .background(backgroundColor, in: .capsule)
            .foregroundColor(foregroundColor)
            .opacity(configuration.isPressed ? 0.6 : 1.0)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    let foregroundColor: Color
    let borderColor: Color
    
    init(foregroundColor: Color = .blue, borderColor: Color = .blue) {
        self.foregroundColor = foregroundColor
        self.borderColor = borderColor
    }
    
    init(_ color: Color = .blue) {
        self.foregroundColor = color
        self.borderColor = color
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .fontWeight(.semibold)
            .foregroundColor(foregroundColor)
            .padding()
            .frame(maxWidth: .infinity)
            .background(
                Capsule()
                    .stroke(borderColor, lineWidth: 2)
            )
            .opacity(configuration.isPressed ? 0.6 : 1.0)
    }
}


    
