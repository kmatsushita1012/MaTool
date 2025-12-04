//
//  Button+.swift
//  MaTool
//
//  Created by 松下和也 on 2025/12/04.
//

import SwiftUI

extension Button where Label == Image {
    init(systemImage: String, action: @escaping @MainActor () -> Void) {
        self.init(action: action) {
            Image(systemName: systemImage)
        }
    }
}
