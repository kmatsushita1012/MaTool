//
//  Button+.swift
//  MaTool
//
//  Created by 松下和也 on 2025/12/04.
//

import SwiftUI

extension Button where Label == SwiftUI.Label<Text, Image> {
    init(systemImage: String, action: @escaping @MainActor () -> Void) {
        self.init("", systemImage: systemImage) {
            action()
        }
    }
}

extension Button where Label == Image {
    init(systemImage: String, role: ButtonRole? = nil, action: @escaping @MainActor () -> Void) {
        self.init(role: role,action: action) {
            Image(systemName: systemImage)
        }
    }
}
