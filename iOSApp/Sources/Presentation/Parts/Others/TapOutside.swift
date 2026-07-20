//
//  TapOutside.swift
//  MaTool
//
//  Created by 松下和也 on 2025/08/06.
//

import SwiftUI

struct TapOutsideModifier: ViewModifier {
    @Binding var isShown: Bool

    @State private var isVisible = false

    func body(content: Content) -> some View {
        ZStack {
            if isVisible {
                Color.clear
                    .contentShape(Rectangle())
                    .ignoresSafeArea()
                    .transition(.opacity)
                    .onTapGesture {
                        withAnimation{
                            isShown = false
                        }
                    }
            }
            content
        }
        .onChange(of: isShown) { isShown in
            withAnimation(.easeInOut(duration: 0.1)) {
                isVisible = isShown
            }
        }
        .onAppear {
            isVisible = isShown
        }
    }
}

extension View {
    func tapOutside(isShown: Binding<Bool>) -> some View {
        self.modifier(TapOutsideModifier(isShown: isShown))
    }
}
